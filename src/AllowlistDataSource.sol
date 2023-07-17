pragma solidity ^0.8.19;

contract AllowlistDataSource {
    error NOT_ALLOWED();

    mapping(address => bool) public allowed;

    function isAllowed(address _address) public view returns (bool) {
        return allowed[_address];
    }
}
