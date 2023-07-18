// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.17;

// import "forge-std/Test.sol";
// import {IAllowlistDataSource} from "../src/AllowlistDataSourceAggregator.sol";
// import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
// import {IJBDirectory} from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBDirectory.sol";
// import {IJBFundingCycleDataSource3_1_1} from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBFundingCycleDataSource3_1_1.sol";
// import {IJBPayDelegate3_1_1} from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBPayDelegate3_1_1.sol";
// import {IJBPaymentTerminal} from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBPaymentTerminal.sol";
// import {IJBRedemptionDelegate3_1_1} from "@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBRedemptionDelegate3_1_1.sol";
// import {JBPayParamsData} from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBPayParamsData.sol";
// import {JBDidPayData3_1_1} from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBDidPayData3_1_1.sol";
// import {JBDidRedeemData3_1_1} from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBDidRedeemData3_1_1.sol";
// import {JBRedeemParamsData} from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBRedeemParamsData.sol";
// import {JBPayDelegateAllocation3_1_1} from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBPayDelegateAllocation3_1_1.sol";
// import {JBRedemptionDelegateAllocation3_1_1} from "@jbx-protocol/juice-contracts-v3/contracts/structs/JBRedemptionDelegateAllocation3_1_1.sol";
// import {DeployMyDelegateData} from "src/structs/DeployMyDelegateData.sol";

// contract DummyDataSource is IAllowlistDataSource {
//     mapping(address => bool) public allowed;

//     constructor(address[] memory allowedAddresses) {
//         for (uint256 i = 0; i < allowedAddresses.length; i++) {
//             allowed[allowedAddresses[i]] = true;
//         }
//     }

//     function isAllowed(address _address) external view override returns (bool) {
//         return allowed[_address];
//     }
// }

// contract MyDelegateTest_Unit is Test, IJBFundingCycleDataSource3_1_1,
//     IJBPayDelegate3_1_1,
//     IJBRedemptionDelegate3_1_1 {
//     address private allowedPayer = address(0x123);
//     address private notAllowedPayer = address(0x456);
//     uint256 private projectId = 1;
//     IJBDirectory private directory;
//     address[] private dataSources;

//     struct JBTokenAmount {
//         address token;
//         uint256 value;
//         uint256 decimals;
//         uint256 currency;
//     }

//     function setUp() public {
//         address[] memory allowedAddresses = new address[](1);
//         allowedAddresses[0] = allowedPayer;
//         DummyDataSource ds1 = new DummyDataSource(allowedAddresses);
//         DummyDataSource ds2 = new DummyDataSource(allowedAddresses);
//         dataSources.push(address(ds1));
//         dataSources.push(address(ds2));

//         directory = IJBDirectory(address(this));

//         DeployMyDelegateData memory initData = DeployMyDelegateData(dataSources);
//         initialize(projectId, directory, initData);
//     }

//     function testInitialize() public {
//         assertTrue(dataSources.length == getDataSourcesLength(), "Initialisation failed");
//     }

//     function testPayparams() public
//     {
        
//     }

//     error INVALID_PAYMENT_EVENT(address caller, uint256 projectId, uint256 value);
//     error INVALID_REDEMPTION_EVENT(address caller, uint256 projectId, uint256 value);
//     error PAYER_NOT_ON_ALLOWLIST(address payer);

//     function payParams(JBPayParamsData calldata _data)
//         external
//         view
//         override
//         returns (uint256 weight, string memory memo, JBPayDelegateAllocation3_1_1[] memory delegateAllocations)
//     {
//         bool isAllowed = false;

//         for (uint256 i = 0; i < dataSources.length; i++) {
//             IAllowlistDataSource dataSource = IAllowlistDataSource(dataSources[i]);
//             if (dataSource.isAllowed(_data.payer)) {
//                 isAllowed = true;
//                 break;
//             }
//         }

//         if (!isAllowed) revert PAYER_NOT_ON_ALLOWLIST(_data.payer);

//         weight = _data.weight;
//         memo = _data.memo;

//         delegateAllocations = new JBPayDelegateAllocation3_1_1[](1);
//         delegateAllocations[0] = JBPayDelegateAllocation3_1_1(this, 0, "");
//     }

//     // Functionality from AllowlistDataSourceAggregator.sol
//     function initialize(
//         uint256 _projectId,
//         IJBDirectory _directory,
//         DeployMyDelegateData memory _data
//     ) public {
//         projectId = _projectId;
//         directory = _directory;
//         dataSources = _data.dataSources;
//     }

//     function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool) {
//         return _interfaceId == type(IJBFundingCycleDataSource3_1_1).interfaceId
//             || _interfaceId == type(IJBPayDelegate3_1_1).interfaceId
//             || _interfaceId == type(IJBRedemptionDelegate3_1_1).interfaceId;
//     }

//     function didRedeem(JBDidRedeemData3_1_1 calldata _data) external payable virtual override {
//         // Make sure the caller is a terminal of the project, and that the call is being made on behalf of an interaction with the correct project.
//         if (
//             msg.value != 0 || !directory.isTerminalOf(projectId, IJBPaymentTerminal(msg.sender))
//                 || _data.projectId != projectId
//         ) revert INVALID_REDEMPTION_EVENT(msg.sender, _data.projectId, msg.value);
//     }

//     /// @notice Received hook from the payment terminal after a payment.
//     /// @dev Reverts if the calling contract is not one of the project's terminals.
//     /// @param _data Standard Juicebox project payment data. See https://docs.juicebox.money/dev/api/data-structures/jbdidpaydata/.
//     function didPay(JBDidPayData3_1_1 calldata _data) external payable virtual override {
//         // Make sure the caller is a terminal of the project, and that the call is being made on behalf of an interaction with the correct project.
//         if (
//             msg.value != 0 || !directory.isTerminalOf(projectId, IJBPaymentTerminal(msg.sender))
//                 || _data.projectId != projectId
//         ) revert INVALID_PAYMENT_EVENT(msg.sender, _data.projectId, msg.value);
//     }

//     function redeemParams(JBRedeemParamsData calldata _data)
//         external
//         view
//         virtual
//         override
//         returns (
//             uint256 reclaimAmount,
//             string memory memo,
//             JBRedemptionDelegateAllocation3_1_1[] memory delegateAllocations
//         )
//     {
//         // Forward the default reclaimAmount received from the protocol.
//         reclaimAmount = _data.reclaimAmount.value;
//         // Forward the default memo received from the redeemer.
//         memo = _data.memo;
//         // Add `this` contract as a Redeem Delegate so that it receives a `didRedeem` call. Don't send any extra funds to the delegate.
//         delegateAllocations = new JBRedemptionDelegateAllocation3_1_1[](1);
//         delegateAllocations[0] = JBRedemptionDelegateAllocation3_1_1(this, 0, "");
//     }

//     function getDataSourcesLength() public view returns (uint256) {
//         return dataSources.length;
//     }

//     function isAllowed(address _address) public view returns (bool) {
//         for (uint256 i = 0; i < dataSources.length; i++) {
//             IAllowlistDataSource dataSource = IAllowlistDataSource(dataSources[i]);
//             if (dataSource.isAllowed(_address)) {
//                 return true;
//             }
//         }
//         return false;
//     }
//     // End of functionality from AllowlistDataSourceAggregator.sol
// }
