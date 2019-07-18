pragma solidity 0.5.8;

contract Owned {
    address private owner;

    event LogOwnerChanged(address indexed originalOwner, address indexed newOwner);

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner()  {
        require(msg.sender == owner, 'Only owner allowed!');
        _;
    }

    function changeOwner(address newOwner) public onlyOwner {
        require(newOwner != address(0), 'Cannot renounce ownership!');

        owner = newOwner;

        emit LogOwnerChanged(owner, newOwner);
    }
}
