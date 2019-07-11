pragma solidity 0.5.8;

contract Owned {
    address public owner = msg.sender;

    modifier onlyOwner()  {
        require(msg.sender == owner, 'Only owner allowed!');
        _;
    }

    function changeOwner(address newOwner) public onlyOwner {
        owner = newOwner;
    }
}

contract Splitter is Owned {
    struct Peer {
        uint256 index;
        uint256 balance;
    }
    address[] public peers;
    mapping (address => Peer) public peerMap;

    event LogAddPeer(address indexed owner, address indexed peer);
    event LogRemovePeer(address indexed owner, address indexed peer);
    event LogSplit(address indexed initiator, uint indexed peers);
    event LogClaim(address indexed initiator, uint indexed amount);

    function getPeerCount() external view returns (uint256) {
        return peers.length;
    }

    function addPeer(address peer) external onlyOwner {
        require(peerMap[peer].index == 0, 'Peer already part of contract');

        peerMap[peer] = Peer(peers.length + 1, 0);
        peers.push(peer);

        emit LogAddPeer(owner, peer);
    }

    function removePeer(address peer) external onlyOwner {
        require(peerMap[peer].index > 0, 'Peer not part of contract');

        uint256 peerIndex = peerMap[peer].index;

        delete peerMap[peer];
        peers[peerIndex - 1] = peers[peers.length - 1];
        peerMap[peers[peerIndex - 1]].index = peerIndex;
        delete peers[peers.length - 1];
        peers.length--;

        emit LogRemovePeer(owner, peer);
    }

    function split() external payable {
        require(msg.value > 0, 'Invalid amount!');

        uint256 amount = msg.value / peers.length;

        for (uint256 i = 0; i < peers.length; i++) {
            uint256 newBalance = peerMap[peers[i]].balance + amount;
            require(newBalance >= peerMap[peers[i]].balance, 'Balance overflow!');
            peerMap[peers[i]].balance = newBalance;
        }

        emit LogSplit(msg.sender, peers.length);
    }

    function claim(uint256 amount) external {
        require(peerMap[msg.sender].balance >= amount, 'Insufficient balance!');

        peerMap[msg.sender].balance -= amount;
        msg.sender.transfer(amount);

        emit LogClaim(msg.sender, amount);
    }
}
