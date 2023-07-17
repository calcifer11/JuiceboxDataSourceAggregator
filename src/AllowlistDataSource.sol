import '@jbx-protocol/contracts-v2/contracts/interfaces/IJBFundingCycleDataSource.sol';

contract AllowlistDataSource is IJBFundingCycleDataSource {
  error NOT_ALLOWED();

 
  mapping(address => bool) public allowed;

  function isAllowed(address _address) public view returns (bool) {
    return allowed[_address];
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
    if (!allowed[_data.payer]) revert NOT_ALLOWED();

    // Forward the recieved weight and memo, and use no delegate.
    return (_data.weight, _data.memo, IJBPayDelegate(address(0)));
  }

  // This is unused but needs to be included to fulfill IJBFundingCycleDataSource.
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
    // Return the default values.
    return (_data.reclaimAmount.value, _data.memo, IJBRedemptionDelegate(address(0)));
  }
}