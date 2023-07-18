// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/structs/LaunchProjectData.sol";
import "../src/structs/LaunchFundingCyclesData.sol";
import "../src/structs/DeployMyDelegateData.sol";
import "./helpers/TestBaseWorkflowV3.sol";
import "@jbx-protocol/juice-delegates-registry/src/JBDelegatesRegistry.sol";
import {JBPayDelegateAllocation} from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBPayDelegateAllocation.sol";

import {AllowlistDataSourceAggregator} from "../src/AllowlistDataSourceAggregator.sol";
import {IAllowlistDataSource} from "../src/AllowlistDataSourceAggregator.sol";
import {AllowlistDataSourceAggregatorDeployer} from "../src/AllowlistDataSourceAggregatorDeployer.sol";
import {IJBDelegatesRegistry} from "@jbx-protocol/juice-delegates-registry/src/interfaces/IJBDelegatesRegistry.sol";
import {IJBFundingCycleBallot} from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBFundingCycleBallot.sol";
import {JBGlobalFundingCycleMetadata} from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBFundingCycleMetadata.sol";
import {AllowlistDataSourceAggregatorProjectDeployer} from "../src/AllowlistDataSourceAggregatorProjectDeployer.sol";

contract DummyDataSource is IAllowlistDataSource {
    mapping(address => bool) public allowed;

    constructor(address[] memory allowedAddresses) {
        for (uint256 i = 0; i < allowedAddresses.length; i++) {
            allowed[allowedAddresses[i]] = true;
        }
    }

    function isAllowed(address _address) external view override returns (bool) {
        return allowed[_address];
    }
}


// Inherits from "./helpers/TestBaseWorkflowV3.sol", called by super.setUp()
contract MyDelegateTest_Integration_Unit is TestBaseWorkflowV3 {
    using JBFundingCycleMetadataResolver for JBFundingCycle;

    // Project setup params
    JBProjectMetadata _projectMetadata;
    JBFundingCycleData _data;
    JBFundingCycleMetadata _metadata;
    JBFundAccessConstraints[] _fundAccessConstraints; // Default empty
    IJBPaymentTerminal[] _terminals; // Default empty
    JBPayParamsData _payParamsData;

    JBTokenAmount _tokenAmount;


    // Delegate setup params
    JBDelegatesRegistry delegatesRegistry;
    AllowlistDataSourceAggregator _delegateImpl;
    AllowlistDataSourceAggregatorDeployer _delegateDepl;
    DeployMyDelegateData delegateData;
    AllowlistDataSourceAggregatorProjectDeployer projectDepl;

    address[] private dataSources;
    // Assigned when project is launched
    uint256 _projectId;

    // Used in JBFundingCycleMetadata
    uint256 reservedRate = 4500;

    // Used in JBFundingCycleData
    uint256 weight = 10 ** 18; // Minting 1 token per eth

    function setUp() public override {
        // Provides us with _jbOperatorStore and _jbETHPaymentTerminal
        super.setUp();

        /* 
        This setup follows a DelegateProjectDeployer pattern like in https://docs.juicebox.money/dev/extensions/juice-721-delegate/
        It deploys a new JB project and funding cycle, and then attaches our delegate to that funding cycle as a DataSource and Delegate.
        */

        // Placeholder project metadata, would customize this in prod.
        _projectMetadata = JBProjectMetadata({content: "myIPFSHash", domain: 1});

        // https://docs.juicebox.money/dev/extensions/juice-delegates-registry/jbdelegatesregistry/
        delegatesRegistry = new JBDelegatesRegistry(IJBDelegatesRegistry(address(0)));

        // Instance of our delegate code
        _delegateImpl = new AllowlistDataSourceAggregator();

        // Required for our custom project deployer below, eventually attaches the delegate to the funding cycle.
        _delegateDepl = new AllowlistDataSourceAggregatorDeployer(_delegateImpl, delegatesRegistry);

        // Custom deployer
        projectDepl = new AllowlistDataSourceAggregatorProjectDeployer(_delegateDepl, _jbOperatorStore);


        // The following describes the funding cycle, access constraints, and metadata necessary for our project.
        _data = JBFundingCycleData({
            duration: 30 days,
            weight: weight,
            discountRate: 0,
            ballot: IJBFundingCycleBallot(address(0))
        });

        _metadata = JBFundingCycleMetadata({
            global: JBGlobalFundingCycleMetadata({
                allowSetTerminals: false,
                allowSetController: false,
                pauseTransfers: false
            }),
            reservedRate: reservedRate,
            redemptionRate: 5000,
            ballotRedemptionRate: 0,
            pausePay: false,
            pauseDistributions: false,
            pauseRedeem: false,
            pauseBurn: false,
            allowMinting: true,
            preferClaimedTokenOverride: false,
            allowTerminalMigration: false,
            allowControllerMigration: false,
            holdFees: false,
            useTotalOverflowForRedemptions: false,
            useDataSourceForPay: true,
            useDataSourceForRedeem: false,
            dataSource: address(0),
            metadata: 0
        });

        _fundAccessConstraints.push(
            JBFundAccessConstraints({
                terminal: _jbETHPaymentTerminal,
                token: jbLibraries().ETHToken(),
                distributionLimit: 2 ether,
                overflowAllowance: type(uint232).max,
                distributionLimitCurrency: 1, // Currency = ETH
                overflowAllowanceCurrency: 1
            })
        );

        // Imported from TestBaseWorkflowV3.sol via super.setUp() https://docs.juicebox.money/dev/learn/architecture/terminals/
        _terminals = [_jbETHPaymentTerminal];

        JBGroupedSplits[] memory _groupedSplits = new JBGroupedSplits[](1); // Default empty

        // Our delegate has an datasources functionality, create a mock list of two addresses for testing.
        address[] memory allowedAddresses = new address[](2);
        allowedAddresses[0] = address(123);
        allowedAddresses[1] = address(456);
        DummyDataSource ds1 = new DummyDataSource(allowedAddresses);
        DummyDataSource ds2 = new DummyDataSource(allowedAddresses);
        dataSources.push(address(ds1));
        dataSources.push(address(ds2));

        // The imported struct used by our delegate
        delegateData = DeployMyDelegateData({
            dataSources: dataSources,
            governance: msg.sender
        });


        // Assemble all of our previous configuration for our project deployer
         LaunchProjectData memory launchProjectData = LaunchProjectData({
            projectMetadata: _projectMetadata,
            data: _data,
            metadata: _metadata,
            mustStartAtOrAfter: 0,
            groupedSplits: _groupedSplits,
            fundAccessConstraints: _fundAccessConstraints,
            terminals: _terminals,
            memo: ""
        });

         _tokenAmount  = JBTokenAmount ({
            token : jbLibraries().ETHToken(),
            value: 1 ether,
            decimals: 18,
            currency: 1
        });


        // Blastoff
        _projectId = projectDepl.launchProjectFor(
            address(123),
            delegateData,
            launchProjectData,
            _jbController
        );


        // PayParams struct
        _payParamsData = JBPayParamsData({
            terminal: _jbETHPaymentTerminal,
            payer : address(123),
            amount : _tokenAmount,
            projectId : _projectId,
            currentFundingCycleConfiguration : 0,
            beneficiary: _beneficiary,
            weight: weight,
            reservedRate: reservedRate,
            memo: "",
            metadata: "0x3333" 

        });
    }

    function testFail_PaymentFromUnAllowed() public {
        vm.deal(address(124), 1 ether);
        vm.prank(address(124));
        _jbETHPaymentTerminal.pay{value: 1 ether}(
            1,
            0,
            address(0),
            _beneficiary,
            /* _minReturnedTokens */
            0,
            /* _preferClaimedTokens */
            false,
            /* _memo */
            "Take my money!",
            /* _delegateMetadata */
            ""
        );

    }

    /* 
    function pay(
    uint256 _projectId,
    uint256 _amount,
    address _token,
    address _beneficiary,
    uint256 _minReturnedTokens,
    bool _preferClaimedTokens,
    string calldata _memo,
    bytes calldata _metadata
    )
    */

    function test_PaymentFromAllowed() public {
        emit log_uint(address(_jbETHPaymentTerminal).balance);

        bytes memory metadata = abi.encode(new bytes(0), new bytes(0), 1 ether);

        vm.deal(address(123), 1 ether);
        vm.prank(address(123));
        _jbETHPaymentTerminal.pay{value: 1 ether}(
            1,
            1 ether,
            address(0),
            _beneficiary,
            /* _minReturnedTokens */
            0,
            /* _preferClaimedTokens */
            true,
            /* _memo */
            "Take my money!",
            /* _delegateMetadata */
            metadata
        );

        emit log_uint(address(_jbETHPaymentTerminal).balance);
        emit log_uint(address(0xCDfc4483dfC62f9072de6b740b996EB0E295A467).balance);

    }

    
    function test_Initialize() public {
        assertTrue(delegateData.dataSources.length == _delegateImpl.getDataSourcesLength(), "Initialisation failed");
    }

    function test_payParams() public { 
        address[] memory _dataSources = _delegateImpl.getDataSources();
        for (uint256 i = 0; i < _dataSources.length; i++) {
        emit log_named_address("ds", _dataSources[i]);
        }
      (uint256 _weight, , ) = _delegateImpl.payParams(_payParamsData);
      emit log_named_uint("weight", _weight);
    }


}