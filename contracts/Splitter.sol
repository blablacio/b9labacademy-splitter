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
    event LogSplit(address indexed initiator, address[] peers, uint256 amount);
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

    function getPeers() external view returns (address[] memory) {
        return peers;
    }

    function addPeer(address peer) external onlyOwner {
        require(peerMap[peer].index == 0, 'Peer already part of contract');
        require(peers.length < peerCap, 'Peer cap reached');

        peerMap[peer] = Peer(peers.push(peer), peerMap[peer].balance);

        emit LogPeerAdded(msg.sender, peer);
    }

    function removePeer(uint oneBasedIndex) external onlyOwner {
        require(oneBasedIndex > 0 && oneBasedIndex <= peers.length, 'Peer not part of contract');

        // Get requested peer
        address peer = peers[oneBasedIndex - 1];

        // Set peer index to 0 to deactivate
        peerMap[peer].index = 0;

        if (peers.length > 1) {
            // Swap removed peer with last peer in array
            peers[oneBasedIndex - 1] = peers[peers.length - 1];
            // Change swapped peer index to removed peer index
            peerMap[peers[oneBasedIndex - 1]].index = oneBasedIndex;
            // Delete last peer
            delete peers[peers.length - 1];
        } else {
            // Just remove peer without swapping
            delete peers[oneBasedIndex - 1];
        }

        // Decrement peers array length
        peers.length--;

        emit LogPeerRemoved(msg.sender, peer);
    }

    function split(address[] calldata beneficiaries) external payable {
        require(msg.value > 0, 'Invalid amount!');
        require(
            beneficiaries.length > 0,
            'You need to send to at least one beneficiary'
        );

        uint256 amount = msg.value.div(beneficiaries.length);
        uint256 change = msg.value.mod(beneficiaries.length);

        for (uint256 i = 0; i < beneficiaries.length; i++) {
            peerMap[beneficiaries[i]].balance = peerMap[beneficiaries[i]].balance.add(amount);
        }

        if (change > 0) {
            Peer memory peer = peerMap[msg.sender];
            peerMap[msg.sender].balance = peer.balance.add(change);
        }

        emit LogSplit(msg.sender, beneficiaries, msg.value);
    }

    function split_all() external payable {
        require(msg.value > 0, 'Invalid amount!');

        uint256 amount = msg.value.div(peers.length);
        uint256 change = msg.value.mod(peers.length);

        for (uint256 i = 0; i < peers.length; i++) {
            peerMap[peers[i]].balance = peerMap[peers[i]].balance.add(amount);
        }

        if (change > 0) {
            Peer memory peer = peerMap[msg.sender];
            peerMap[msg.sender].balance = peer.balance.add(change);
        }

        emit LogSplit(msg.sender, peers, msg.value);
    }

    function claim(uint256 amount) external {
        require(peerMap[msg.sender].index > 0, 'Peer not part of contract!');
        require(peerMap[msg.sender].balance >= amount, 'Insufficient balance!');

        peerMap[msg.sender].balance.sub(amount);

        emit LogClaimed(msg.sender, amount);

        msg.sender.transfer(amount);
    }
}
