import { ethers, run, upgrades } from "hardhat";
import dotenv from "dotenv";

dotenv.config({ path: "../.env" });

async function main() {
  const proxyAddress = process.env.EAS_WRAPPED_PROXY_ADDRESS ?? "";
  console.log("Upgrading EASWrappedVeraxPortal, with proxy at", proxyAddress);
  const EASWrappedVeraxPortal = await ethers.getContractFactory("EASWrappedVeraxPortal");
  await upgrades.upgradeProxy(proxyAddress, EASWrappedVeraxPortal);
  const implementationAddress = await upgrades.erc1967.getImplementationAddress(proxyAddress);

  // await run("verify:verify", {
  //   address: proxyAddress,
  // });

  console.log(`EASWrappedVeraxPortal successfully upgraded and verified!`);
  console.log(`Proxy is at ${proxyAddress}`);
  console.log(`Implementation is at ${implementationAddress}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
