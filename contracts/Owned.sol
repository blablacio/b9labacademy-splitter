pragma solidity 0.5.8;

contract Owned {
    address private _owner;

    event LogOwnerChanged(address indexed originalOwner, address indexed newOwner);

    constructor() public {
        _owner = msg.sender;
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner()  {
        require(msg.sender == _owner, 'Only owner allowed!');
        _;
    }

    function changeOwner(address newOwner) public onlyOwner {
        require(newOwner != address(0), 'Cannot renounce ownership!');

        _owner = newOwner;

        emit LogOwnerChanged(_owner, newOwner);
    }
}
