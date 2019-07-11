const BN = web3.utils.BN;
const Splitter = artifacts.require('./Splitter.sol');


contract('Splitter', accounts => {
  const owner = accounts[0];
  const attacker = accounts[1];
  const user1 = accounts[2];
  const user2 = accounts[3];
  const user3 = accounts[4];

  it('should only enable owner to add peer', async() => {
    const splitter = await Splitter.deployed();
    
    try {
      await splitter.addPeer(user1, { from: attacker });
    } catch (err) {
      assert.equal(err.reason, 'Only owner allowed!');
    }
  });

  it('should only enable owner to remove peer', async() => {
    const splitter = await Splitter.deployed();
    
    try {
      await splitter.removePeer(user1, { from: attacker });
    } catch (err) {
      assert.equal(err.reason, 'Only owner allowed!');
    }
  });

  it('should split between all peers and keep the change', async() => {
    let peerBalancesBefore = new BN(0);
    let peerBalancesAfter = new BN(0);
    const splitter = await Splitter.deployed();
  
    await splitter.addPeer(user1, { from: owner });
    await splitter.addPeer(user2, { from: owner });
    await splitter.addPeer(user3, { from: owner });

    const peerCount = await splitter.getPeerCount();

    for (let i = 0; i < peerCount; i++) {
      let peerAddress = await splitter.peers(i);
      let peer = await splitter.peerMap(peerAddress);
      peerBalancesBefore = peerBalancesBefore.add(peer.balance);
    }
    
    assert.equal(peerBalancesBefore, 0, 'Wrong peer balances!');
    await splitter.split({ value: web3.utils.toWei('0.5', 'ether'), from: owner });

    for (let i = 0; i < peerCount; i++) {
      let peerAddress = await splitter.peers(i);
      let peer = await splitter.peerMap(peerAddress);
      peerBalancesAfter = peerBalancesAfter.add(peer.balance);
    }

    assert.equal(
      peerBalancesAfter,
      (web3.utils.toWei('0.5', 'ether') / 3) * 3,
      'Wrong ending balances!'
    );
  });

  it('should enable peers to claim their balance', async() => {
    const splitter = await Splitter.deployed();

    let peer = await splitter.peerMap(user1);
    let tx = await splitter.claim(peer.balance, { from: user1 });

    assert.isTrue(tx.receipt.status, 'Unexpected error occurred while claiming!');
  });

  it('should not overflow when splitting', async() => {
    const splitter = await Splitter.deployed();
    let amount = new BN(2).pow(new BN(256)).sub(new BN(1));

    await splitter.split({ value: amount, from: owner });
    await splitter.split({ value: amount, from: owner });

    try {
      await splitter.split({ value: amount, from: owner });
    } catch (err) {
      assert.equal(err.reason, 'Balance overflow!');
    }
  });
});
