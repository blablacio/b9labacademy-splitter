pragma solidity 0.5.8;

import "./Owned.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract Splitter is Owned {
    using SafeMath for uint256;

    struct Peer {
        uint256 index;
        uint256 balance;
    }
    address[] public peers;
    mapping (address => Peer) public peerMap;
    /*
    / About 100 - 200 seems to be a reasonable number given:
    / historic gas limits and split() method gas expenditiure.
    */
    uint32 public peerCap;

    event LogPeerAdded(address indexed owner, address indexed peer);
    event LogPeerRemoved(address indexed owner, address indexed peer);
    event LogSplit(address indexed initiator, uint indexed peers);
    event LogClaimed(address indexed initiator, uint indexed amount);

    constructor(uint32 maxPeers) public {
        peerCap = maxPeers;
    }

    function setPeerCap(uint32 maxPeers) external onlyOwner {
        peerCap = maxPeers;
    }

    function getPeerCount() external view returns (uint256) {
        return peers.length;
    }

    function addPeer(address peer) external onlyOwner {
        require(peerMap[peer].index == 0, 'Peer already part of contract');
        require(peers.length < peerCap, 'Peer cap reached');

        peerMap[peer] = Peer(peers.length + 1, 0);
        peers.push(peer);

        emit LogPeerAdded(super.owner(), peer);
    }

    function removePeer(uint index) external onlyOwner {
        require(index > 0 && index < peers.length, 'Peer not part of contract');

        address peer = peers[index];

        delete peerMap[peer];
        peers[index - 1] = peers[peers.length - 1];
        peerMap[peers[index - 1]].index = index;
        delete peers[peers.length - 1];
        peers.length--;

        emit LogPeerRemoved(super.owner(), peer);
    }

    function split(address[] calldata beneficiaries) external payable {
        require(msg.value > 0, 'Invalid amount!');
        require(
            beneficiaries.length > 0,
            'You need to send to at least one beneficiary'
        );
        uint256 amount;
        uint256 change;

        amount = msg.value.div(beneficiaries.length);
        change = msg.value.mod(beneficiaries.length);

        for (uint256 i = 0; i < beneficiaries.length; i++) {
            Peer memory peer = peerMap[beneficiaries[i]];
            peerMap[beneficiaries[i]].balance = peer.balance.add(amount);
        }

        if (change > 0) {
            Peer memory peer = peerMap[msg.sender];
            peerMap[msg.sender].balance = peer.balance.add(change);
        }

        emit LogSplit(msg.sender, beneficiaries.length);
    }

    function split_all() external payable {
        require(msg.value > 0, 'Invalid amount!');
        uint256 amount;
        uint256 change;

        amount = msg.value.div(peers.length);
        change = msg.value.mod(peers.length);

        for (uint256 i = 0; i < peers.length; i++) {
            Peer memory peer = peerMap[peers[i]];
            peerMap[peers[i]].balance = peer.balance.add(amount);
        }

        if (change > 0) {
            Peer memory peer = peerMap[msg.sender];
            peerMap[msg.sender].balance = peer.balance.add(change);
        }

        emit LogSplit(msg.sender, peers.length);
    }

    function claim(uint256 amount) external {
        require(peerMap[msg.sender].index > 0, 'Peer not part of contract!');
        require(peerMap[msg.sender].balance >= amount, 'Insufficient balance!');

        peerMap[msg.sender].balance.sub(amount);
        msg.sender.transfer(amount);

        emit LogClaimed(msg.sender, amount);
    }
}
