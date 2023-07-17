// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBFundingCycleDataSource.sol';
import "@jbx-protocol/juice-contracts-v3/contracts/structs/JBRedeemParamsData.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

interface IAllowlistDataSource {
    function isAllowed(address _address) external view returns (bool);
}

contract AllowlistDataSourceAggregator is IJBFundingCycleDataSource, Initializable {
    error NOT_ALLOWED();
    error DATA_SOURCE_NOT_SET();
    
    /// @notice The AllowList data source contracts this contract's functionality applies to.
    address[] public dataSources;
    
    /// @notice The Juicebox project ID this contract's functionality applies to.
    uint256 public projectId;

    function initialize(address[] memory _dataSources) public initializer {
        require(_dataSources.length > 0, "Data sources should not be empty");
        dataSources = _dataSources;
    }

    function payParams(JBPayParamsData calldata _data)
        external
        view
        override
        returns (
          uint256 weight,
          string memory memo,
          IJBPayDelegate delegate
        )
    {
        bool isAllowed = false;

        for (uint i = 0; i < dataSources.length; i++) {
            IAllowlistDataSource dataSource = IAllowlistDataSource(dataSources[i]);
            if (dataSource.isAllowed(_data.payer)) {
                isAllowed = true;
                break;
            }
        }

        if (!isAllowed) revert NOT_ALLOWED();

        return (_data.weight, _data.memo, IJBPayDelegate(address(0)));
    }

    function redeemParams(JBRedeemParamsData calldata _data)
        external
        pure
        override
        returns (
          uint256 reclaimAmount,
          string memory memo,
          IJBRedemptionDelegate delegate
        )
    {
        return (_data.reclaimAmount.value, _data.memo, IJBRedemptionDelegate(address(0)));
    }

    function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool) {
        return _interfaceId == type(IJBFundingCycleDataSource3_1_1).interfaceId;
    }
}