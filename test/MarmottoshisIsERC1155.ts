import { expect } from "chai";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { ethers } from "hardhat";

describe("Marmottoshis", () => {
  const deployOneYearLockFixture = async () => {
    const [owner, otherAccount] = await ethers.getSigners();

    const Marmottoshis = await ethers.getContractFactory(
      "MarmottoshisIsERC1155"
    );
    const marmottoshis = await Marmottoshis.deploy(owner.address, "uri");

    return { owner, otherAccount, marmottoshis };
  };
  describe("A user", () => {
    it("can't book a mint when reservation is not opened", async () => {
      const { marmottoshis } = await loadFixture(deployOneYearLockFixture);
      await expect(marmottoshis.reservationForWhitelist()).to.be.revertedWith(
        "Reservation for whitelist is not open"
      );
    });
    it("can't book a mint when current step is not 1", async () => {
      const { marmottoshis } = await loadFixture(deployOneYearLockFixture);
      await marmottoshis.updateStep(1);
      await expect(marmottoshis.reservationForWhitelist()).to.be.revertedWith(
        "Not enough ether"
      );
    });
    it("can book a mint", async () => {
      const { marmottoshis, owner } = await loadFixture(
        deployOneYearLockFixture
      );
      await marmottoshis.updateStep(1);
      await marmottoshis.reservationForWhitelist({
        value: ethers.utils.parseEther("0.0001"),
      });
      expect(await marmottoshis.reservationList(owner.address)).to.be.true;
    });
    it("can't book a mint if already in the pre-whitelist", async () => {
      const { marmottoshis } = await loadFixture(deployOneYearLockFixture);
      await marmottoshis.updateStep(1);
      await marmottoshis.reservationForWhitelist({
        value: ethers.utils.parseEther("0.0001"),
      });
      await expect(
        marmottoshis.reservationForWhitelist({
          value: ethers.utils.parseEther("0.0001"),
        })
      ).to.be.revertedWith("You are already in the pre-whitelist");
    });
    // TODO: test revert with "Max pre-whitelist reached"
    it("can't mint when current step is 0, 1 or 7", async () => {
      const { marmottoshis } = await loadFixture(deployOneYearLockFixture);
      const _proof = ethers.utils.formatBytes32String("0");
      await expect(marmottoshis.mint(0, [_proof])).to.be.revertedWith(
        "Sale is not open"
      );
      await marmottoshis.updateStep(1);
      await expect(marmottoshis.mint(0, [_proof])).to.be.revertedWith(
        "Sale is not open"
      );
      await marmottoshis.updateStep(7);
      await expect(marmottoshis.mint(0, [_proof])).to.be.revertedWith(
        "Sale is not open"
      );
    });
    it("can't mint id 0", async () => {
      const { marmottoshis } = await loadFixture(deployOneYearLockFixture);
      const _proof = ethers.utils.formatBytes32String("0");
      await marmottoshis.updateStep(2);
      await expect(marmottoshis.mint(0, [_proof])).to.be.revertedWith(
        "Nonexistent id"
      );
    });
  });
});
