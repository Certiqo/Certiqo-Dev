var certiqo = artifacts.require("Certiqo");

module.exports = function (deployer) {
  deployer.deploy(certiqo, "0xc48231b5f3a7473b51fd52a7408b5e5789d89ed2d03399889d37a73a657a02b3");
};