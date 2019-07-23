const Splitter = artifacts.require("Splitter");

module.exports = function(deployer) {
  deployer.deploy(Splitter, 100, false);
};
