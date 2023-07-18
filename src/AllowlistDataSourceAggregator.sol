// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// import {mulDiv} from '@prb/math/src/Common.sol';
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IJBDirectory} from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBDirectory.sol";
import {IJBFundingCycleDataSource3_1_1} from
    "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBFundingCycleDataSource3_1_1.sol";
import {IJBPayDelegate3_1_1} from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBPayDelegate3_1_1.sol";
import {IJBPaymentTerminal} from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBPaymentTerminal.sol";
import {IJBRedemptionDelegate3_1_1} from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBRedemptionDelegate3_1_1.sol";
import {JBPayParamsData} from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBPayParamsData.sol";
import {JBDidPayData3_1_1} from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBDidPayData3_1_1.sol";
import {JBDidRedeemData3_1_1} from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBDidRedeemData3_1_1.sol";
import {JBRedeemParamsData} from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBRedeemParamsData.sol";
import {JBPayDelegateAllocation3_1_1} from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBPayDelegateAllocation3_1_1.sol";
import {JBRedemptionDelegateAllocation3_1_1} from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBRedemptionDelegateAllocation3_1_1.sol";
import {DeployMyDelegateData} from "./structs/DeployMyDelegateData.sol";


/// @notice A contract meant for aggregating allow lists from various data sources

//Interface to interact with contracts providing lists of allowed payers using isAllowed.
interface IAllowlistDataSource {
    function isAllowed(address _address) external view returns (bool);
}

contract AllowlistDataSourceAggregator is
    IJBFundingCycleDataSource3_1_1,
    IJBPayDelegate3_1_1,
    IJBRedemptionDelegate3_1_1
{
    error INVALID_PAYMENT_EVENT(address caller, uint256 projectId, uint256 value);
    error INVALID_REDEMPTION_EVENT(address caller, uint256 projectId, uint256 value);
    error PAYER_NOT_ON_ALLOWLIST(address payer);

    /// @notice The Juicebox project ID this contract's functionality applies to.
    uint256 public projectId;
    /// @dev Wallet that can add and remove data sources.
    address public governance;
    /// @dev the data sources to collect allow lists from.
    address[] public dataSources;
    /// @notice The directory of terminals and controllers for projects.
    IJBDirectory public directory;

    constructor() 
    {
    }

    modifier onlyGovernance()
    {
        require(msg.sender == governance, "Must be Governance.");
        _;
    }

    /// @dev Add a new data source.
    function addDataSource(address newSource) external onlyGovernance
    {
        dataSources.push(newSource);
    }

    /// @dev Remove a data source at a specified index.
    function removeDataSource(uint256 index) external onlyGovernance {
    require(index < dataSources.length, "Index out of range");
    // Move the last element to the position of the element to be removed
    dataSources[index] = dataSources[dataSources.length - 1];
    // Remove the last element
    dataSources.pop();
    }

    /// @notice This function gets called when the project receives a payment.
    /// @dev Part of IJBFundingCycleDataSource.
    /// @dev Takes allow lists from various data sources and aggregates them to a single allow list before passing it on.
    function payParams(JBPayParamsData calldata _data)
        external
        view
        virtual
        override
        returns (uint256 weight, string memory memo, JBPayDelegateAllocation3_1_1[] memory delegateAllocations)
    {
        bool isAllowed = false;

        for (uint256 i = 0; i < dataSources.length; i++) {
            IAllowlistDataSource dataSource = IAllowlistDataSource(dataSources[i]);
            if (dataSource.isAllowed(_data.payer)) {
                isAllowed = true;
                break;
            }
        }

        if (!isAllowed) revert PAYER_NOT_ON_ALLOWLIST(_data.payer);
        // Forward the default weight received from the protocol.
        weight = _data.weight;
        // Forward the default memo received from the payer.
        memo = _data.memo;
        // Add `this` contract as a Pay Delegate so that it receives a `didPay` call. Don't send any funds to the delegate (keep all funds in the treasury).
        delegateAllocations = new JBPayDelegateAllocation3_1_1[](1);
        delegateAllocations[0] = JBPayDelegateAllocation3_1_1(this, 0, "");
    }

     /// @notice This function gets called when the project's token holders redeem.
    /// @dev Part of IJBFundingCycleDataSource.
    function redeemParams(JBRedeemParamsData calldata _data)
        external
        view
        virtual
        override
        returns (uint256 reclaimAmount, string memory memo, JBRedemptionDelegateAllocation3_1_1[] memory delegateAllocations)
    {
        // Forward the default reclaimAmount received from the protocol.
        reclaimAmount = _data.reclaimAmount.value;
        // Forward the default memo received from the redeemer.
        memo = _data.memo;
        // Add `this` contract as a Redeem Delegate so that it receives a `didRedeem` call. Don't send any extra funds to the delegate.
        delegateAllocations = new JBRedemptionDelegateAllocation3_1_1[](1);
        delegateAllocations[0] = JBRedemptionDelegateAllocation3_1_1(this, 0, '');
    }

    /// @notice Indicates if this contract adheres to the specified interface.
    function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool) {
        return _interfaceId == type(IJBFundingCycleDataSource3_1_1).interfaceId
            || _interfaceId == type(IJBPayDelegate3_1_1).interfaceId
            || _interfaceId == type(IJBRedemptionDelegate3_1_1).interfaceId;
    }

    /// @notice Initializes the clone contract with project details and a directory from which ecosystem payment terminals and controller can be found.
    function initialize(uint256 _projectId, IJBDirectory _directory, DeployMyDelegateData memory _deployMyDelegateData)
        external
    {
        // Stop re-initialization.
        if (projectId != 0) revert();

        // Store the basics.
        projectId = _projectId;
        directory = _directory;

        //Set governance address
        governance = _deployMyDelegateData.governance;
        
        // Store the data sources.
        uint256 _numberOfDataSources = _deployMyDelegateData.dataSources.length;
        for (uint256 _i = 0; _i < _numberOfDataSources; _i++) {
            dataSources.push(_deployMyDelegateData.dataSources[_i]);
        }
    }

    // Get length of dataSources for tests
    function getDataSourcesLength() public view returns (uint256) {
        return dataSources.length;
    }

    // Ge dataSources for tests
    function getDataSources() public view returns (address[] memory _dataSources) {
        return dataSources;
    }

    /// @notice Received hook from the payment terminal after a payment.
    /// @dev Reverts if the calling contract is not one of the project's terminals.
    /// @param _data Standard Juicebox project payment data. See https://docs.juicebox.money/dev/api/data-structures/jbdidpaydata/.
    function didPay(JBDidPayData3_1_1 calldata _data) external payable virtual override {
        // Make sure the caller is a terminal of the project, and that the call is being made on behalf of an interaction with the correct project.
        if (
            msg.value != 0 || !directory.isTerminalOf(projectId, IJBPaymentTerminal(msg.sender))
                || _data.projectId != projectId
        ) revert INVALID_PAYMENT_EVENT(msg.sender, _data.projectId, msg.value);
    }

    /// @notice Received hook from the payment terminal after a redemption.
    /// @dev Reverts if the calling contract is not one of the project's terminals.
    /// @param _data Standard Juicebox project redemption data. See https://docs.juicebox.money/dev/api/data-structures/jbdidredeemdata/.
    function didRedeem(JBDidRedeemData3_1_1 calldata _data) external payable virtual override {
        // Make sure the caller is a terminal of the project, and that the call is being made on behalf of an interaction with the correct project.
        if (
            msg.value != 0 || !directory.isTerminalOf(projectId, IJBPaymentTerminal(msg.sender))
                || _data.projectId != projectId
        ) revert INVALID_REDEMPTION_EVENT(msg.sender, _data.projectId, msg.value);
    }
}
