import { ethers, run, upgrades } from "hardhat";

async function main() {
  console.log("Deploying EASWrappedVeraxPortal...");
  const EASWrappedVeraxPortal = await ethers.getContractFactory("EASWrappedVeraxPortal");
  const portal = await upgrades.deployProxy(EASWrappedVeraxPortal, [[], process.env.ROUTER_ADDRESS], {
    kind: "uups",
  });
  await portal.waitForDeployment();
  const portalProxyAddress = await portal.getAddress();
  const portalImplementationAddress = await upgrades.erc1967.getImplementationAddress(portalProxyAddress);

  // await run("verify:verify", {
  //   address: portalProxyAddress,
  // });

  console.log(`EASWrappedVeraxPortal successfully deployed and verified!`);
  console.log(`Proxy is at ${portalProxyAddress}`);
  console.log(`Implementation is at ${portalImplementationAddress}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
