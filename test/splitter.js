const BN = web3.utils.BN;
const Splitter = artifacts.require('./Splitter.sol');

contract('Splitter', accounts => {
  let splitter;
  const [owner, attacker, user1, user2, user3] = accounts;

  beforeEach('setup contract for each test', async () => {
    splitter = await Splitter.new(100, { from: owner});
  });
  
  it('should only enable owner to add peer', async() => {
    try {
      await splitter.addPeer(user1, { from: attacker });
    } catch (err) {
      assert.strictEqual(err.reason, 'Only owner allowed!');
    }
  });

  it('should only enable owner to remove peer', async() => {
    try {
      await splitter.removePeer(user1, { from: attacker });
    } catch (err) {
      assert.strictEqual(err.reason, 'Only owner allowed!');
    }
  });

  it('should split between all peers and return the change to sender', async() => {
    let peerBalancesBefore = new BN(0);
    let peerBalancesAfter = new BN(0);
    let peers = [user1, user2, owner];

    for (let peerAddress of peers) {
      await splitter.addPeer(peerAddress);
      let peer = await splitter.peerMap(peerAddress);
      peerBalancesBefore = peerBalancesBefore.add(peer.balance);
    }

    let peerCount = await splitter.getPeerCount();
    assert.isTrue(peerCount.eq(new BN(3)), 'Wrong peer count!');

    assert.isTrue(peerBalancesBefore.eq(new BN(0)), 'Wrong peer balances!');
    await splitter.split_all({ value: 5, from: owner });

    for (let peerAddress of peers) {
      let peer = await splitter.peerMap(peerAddress);
      peerBalancesAfter = peerBalancesAfter.add(peer.balance);
    }

    assert.isTrue(
      peerBalancesAfter.eq(new BN(5)),
      'Wrong ending balances!'
    );
  });

  it('should split between selected peers and return the change to sender', async() => {
    let peerBalancesBefore = new BN(0);
    let peerBalancesAfter = new BN(0);
    let peers = [user1, user2, owner];

    for (let peerAddress of peers) {
      let peer = await splitter.peerMap(peerAddress);
      peerBalancesBefore = peerBalancesBefore.add(peer.balance);
    }

    assert.isTrue(peerBalancesBefore.eq(new BN(0)), 'Wrong peer balances!');
    await splitter.split([user1, user2], { value: 3, from: owner });

    for (let peerAddress of peers) {
      let peer = await splitter.peerMap(peerAddress);
      peerBalancesAfter = peerBalancesAfter.add(peer.balance);
    }

    assert.isTrue(
      peerBalancesAfter.eq(new BN(3)),
      'Wrong ending balances!'
    );
  });

  it('should enable peers to claim their balance', async() => {
    await splitter.addPeer(user1, { from: owner });
    await splitter.addPeer(user2, { from: owner });
    await splitter.split([user1, user2], { value: 3, from: owner });

    let startingBalance = new BN(await web3.eth.getBalance(user1));
    let peer = await splitter.peerMap(user1);
    let tx = await splitter.claim(peer.balance, { from: user1, gasPrice: 42 });

    assert.isTrue(tx.receipt.status, 'Unexpected error occurred while claiming!');
    assert.strictEqual(tx.receipt.from, user1.toLowerCase(), 'Wrong recipient found in receipt!');
    peer = await splitter.peerMap(user1);

    assert.isTrue(peer.balance.eq(new BN(0)), 'Incorrect peer balance after claim!');

    let endingBalance = new BN(await web3.eth.getBalance(user1));
    assert.isTrue(
      startingBalance
      .add(new BN(1))
      .sub(new BN(tx.receipt.gasUsed).mul(new BN(42)))
      .eq(endingBalance),
      'Incorrect peer balance on chain!'
      );
  });

  it('should not overflow when splitting', async() => {
    let amount = new BN(2).pow(new BN(256)).sub(new BN(1));

    await splitter.addPeer(owner, { from: owner });
    await splitter.addPeer(user1, { from: owner });
    await splitter.addPeer(user2, { from: owner });

    await splitter.split([user1, user2], { value: amount, from: user1 });
    await splitter.split([user1, user2], { value: amount, from: user2 });

    try {
      await splitter.split([user1, user2], { value: amount, from: owner });
    } catch (err) {
      assert.strictEqual(err.reason, 'SafeMath: addition overflow');
    }
  });

  it('should return proper peer count', async() => {
    await splitter.addPeer(owner, { from: owner });
    await splitter.addPeer(user1, { from: owner });
    await splitter.addPeer(user2, { from: owner });

    let peers = await splitter.getPeers();

    assert.strictEqual(peers.length, 3);
  });

  it('should properly handle peer removal and preserve peer balance', async() => {
    await splitter.addPeer(owner, { from: owner });
    await splitter.addPeer(user1, { from: owner });
    await splitter.addPeer(user2, { from: owner });
    await splitter.split_all({ value: 5, from: owner });

    let peers = await splitter.getPeers();

    assert.strictEqual(peers[0], owner, 'Wrong peer at index 0');
    assert.strictEqual(peers[1], user1, 'Wrong peer at index 1');
    assert.strictEqual(peers[2], user2, 'Wrong peer at index 2');

    let peer = await splitter.peerMap(owner);
    assert.isTrue(peer.index.eq(new BN(1)), 'Wrong index for first peer');
    assert.isTrue(peer.balance.eq(new BN(3)), 'Wrong balance for first peer');

    peer = await splitter.peerMap(user1);
    assert.isTrue(peer.index.eq(new BN(2)), 'Wrong index for second peer');
    assert.isTrue(peer.balance.eq(new BN(1)), 'Wrong balance for second peer');
    
    peer = await splitter.peerMap(user2);
    assert.isTrue(peer.index.eq(new BN(3)), 'Wrong index for third peer');
    assert.isTrue(peer.balance.eq(new BN(1)), 'Wrong balance for third peer');

    await splitter.removePeer(1);

    peers = await splitter.getPeers();

    assert.strictEqual(peers.length, 2, 'Wrong peer count');
    assert.strictEqual(peers[0], user2, 'Wrong peer at index 0');
    assert.strictEqual(peers[1], user1, 'Wrong peer at index 1');

    peer = await splitter.peerMap(user1);
    assert.isTrue(peer.index.eq(new BN(2)), 'Wrong index for first peer');
    assert.isTrue(peer.balance.eq(new BN(1)), 'Wrong balance for first peer');

    peer = await splitter.peerMap(user2);
    assert.isTrue(peer.index.eq(new BN(1)), 'Wrong index for second peer');
    assert.isTrue(peer.balance.eq(new BN(1)), 'Wrong balance for second peer');

    peer = await splitter.peerMap(owner);
    assert.isTrue(peer.index.eq(new BN(0)), 'Wrong index for removed peer');
    assert.isTrue(peer.balance.eq(new BN(3)), 'Wrong balance for removed peer');

    await splitter.removePeer(1);

    peers = await splitter.getPeers();

    assert.strictEqual(peers.length, 1, 'Wrong peer count');
    assert.strictEqual(peers[0], user1, 'Wrong peer at index 0');

    peer = await splitter.peerMap(user1);
    assert.isTrue(peer.index.eq(new BN(1)), 'Wrong index for second peer');
    assert.isTrue(peer.balance.eq(new BN(1)), 'Wrong balance for second peer');

    peer = await splitter.peerMap(owner);
    assert.isTrue(peer.index.eq(new BN(0)), 'Wrong index for first removed peer');
    assert.isTrue(peer.balance.eq(new BN(3)), 'Wrong balance for first removed peer');

    peer = await splitter.peerMap(user2);
    assert.isTrue(peer.index.eq(new BN(0)), 'Wrong index for second removed peer');
    assert.isTrue(peer.balance.eq(new BN(1)), 'Wrong balance for second removed peer');

    await splitter.removePeer(1);

    peers = await splitter.getPeers();
    assert.strictEqual(peers.length, 0, 'Wrong peer count after removing all peers');

    peer = await splitter.peerMap(owner);
    assert.isTrue(peer.index.eq(new BN(0)), 'Wrong peer index in peer map after removing all peers');
    assert.isTrue(peer.balance.eq(new BN(3)), 'Wrong peer balance in peer map after removing all peers');

    peer = await splitter.peerMap(user1);
    assert.isTrue(peer.index.eq(new BN(0)), 'Wrong peer index in peer map after removing all peers');
    assert.isTrue(peer.balance.eq(new BN(1)), 'Wrong peer balance in peer map after removing all peers');
    
    peer = await splitter.peerMap(user2);
    assert.isTrue(peer.index.eq(new BN(0)), 'Wrong peer index in peer map after removing all peers');
    assert.isTrue(peer.balance.eq(new BN(1)), 'Wrong peer balance in peer map after removing all peers');

    try {
      await splitter.removePeer(1);
    } catch (err) {
      assert.strictEqual(err.reason, 'Peer not part of contract');
    }
  });
});
