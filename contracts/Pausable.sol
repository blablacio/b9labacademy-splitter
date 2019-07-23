pragma solidity 0.5.8;

import "./Owned.sol";

contract Pausable is Owned {
    bool private paused;
    bool private killed;

    event LogPaused(address who);
    event LogResumed(address who);
    event LogKilled(address who);

    constructor() internal {
        paused = false;
        killed = false;
    }

    modifier notPaused {
        require(paused == false, 'Contract paused');
        _;
    }

    modifier onlyPaused {
        require(paused == true, 'Contract not paused');
        _;
    }

    modifier notKilled {
        require(killed == false, 'Contract killed');
        _;
    }

    function isPaused() public view returns (bool) {
        return paused;
    }

    function pause() public notKilled notPaused onlyOwner {
        paused = true;

        emit LogPaused(msg.sender);
    }

    function resume() public notKilled onlyPaused onlyOwner {
        paused = false;

        emit LogResumed(msg.sender);
    }

    function isKilled() public view returns (bool) {
        return killed;
    }

    function kill() public onlyOwner {
        require(killed == false, 'Contract already killed');

        killed = true;

        emit LogKilled(msg.sender);
    }
}
