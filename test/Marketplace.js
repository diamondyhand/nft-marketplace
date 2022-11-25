const { ethers, upgrades } = require("hardhat");
const hre = require("hardhat");
const { expect } = require("chai");

describe("Marketplace contract", function () {
  let Marketplace, LandPlot;
  let owner, account1, account2, account3;
  const auctionStatus = {
    STARTED: 0,
    CANCELLED: 1,
    EXPIRED: 2,
    FINISHED: 3,
  };
  const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

  beforeEach(async () => {
    [owner, account1, account2, account3] = await ethers.getSigners();
    const marketplace = await ethers.getContractFactory("Marketplace");
    const landplot = await ethers.getContractFactory("LandPlot");
    LandPlot = await upgrades.deployProxy(landplot, ["LandPlot", "LPT"]);
    Marketplace = await upgrades.deployProxy(marketplace, []);
    await LandPlot.deployed();
    await Marketplace.deployed();

    await LandPlot.admin_set_claim_status(true);
    await LandPlot.connect(account1).claimLands([1, 2], [2, 3], {
      value: 0,
    });
    await LandPlot.connect(account2).claimLands([4], [4], {
      value: 0,
    });
    await LandPlot.connect(account1).approve(Marketplace.address, 2);
    await LandPlot.connect(account1).approve(Marketplace.address, 3);
    await LandPlot.connect(account2).approve(Marketplace.address, 4);
  });

  describe("Auction", () => {
    describe("newAuction test", () => {
      it("check newAuction function", async () => {
        await Marketplace.connect(account1).newAuction(
          LandPlot.address,
          [2],
          10000
        );
        const auctionInfo = await Marketplace.auctionInfos(0);
        const auctionToken = await Marketplace.auctionTokens(0, 0);
        expect(auctionInfo.creator).to.equal(await account1.getAddress());
        expect(auctionInfo.oStatus).to.equal(auctionStatus.STARTED);
        expect(auctionInfo.tokenIdCnt).to.equal(1);
        expect(auctionToken.tokenAddress).to.equal(LandPlot.address);
        expect(auctionToken.tokenId).to.equal(2);
        expect(await Marketplace.auctionInfoCnt()).to.equal(1);
      });

      it("revert if auction creator is not token owner", async () => {
        await expect(Marketplace.connect(account2).newAuction(
          LandPlot.address,
          [3],
          10000
        )).to.be.revertedWith("ERC721: transfer of token that is not own");
      });
    });

    describe("cancelAuction test1", () => {
      beforeEach(async () => {
        await Marketplace.connect(account1).newAuction(
          LandPlot.address,
          [2],
          10000
        );
      });

      it("revert if auctionInfoId is invalid", async () => {
        await expect(
          Marketplace.connect(account2).bidAuction(1, { value: 1000 })
        ).to.be.revertedWith("Invalid auctionInfoId");
      });

      it("check bidAuction function", async () => {
        const balanceBeforeBid = await account2.getBalance();
        await Marketplace.connect(account2).bidAuction(0, { value: 1000 });
        expect(await account2.getBalance()).to.equal(
          balanceBeforeBid.sub(1000)
        );
        const auctionInfo = await Marketplace.auctionInfos(0);
        expect(auctionInfo.topBidder).to.equal(await account2.getAddress());
        expect(auctionInfo.topPrice).to.equal(1000);
      });

      it("check cancelAuction function", async () => {
        await Marketplace.connect(account1).cancelAuction(0);
        const auctionInfo = await Marketplace.auctionInfos(0);
        expect(auctionInfo.oStatus).to.equal(auctionStatus.CANCELLED);
      });

      it("revert if auction time is up", async () => {
        await Marketplace.connect(account1).newAuction(
          LandPlot.address,
          [3],
          10000
        );
        await hre.network.provider.send("evm_increaseTime", [10000]);
        await hre.network.provider.send("evm_mine");
        await expect(
          Marketplace.connect(account2).bidAuction(1, { value: 1000 })
        ).to.be.revertedWith("Time is up");
      });

      it("revert if cancel requester is not creator", async () => {
        await expect(
          Marketplace.connect(account2).cancelAuction(0)
        ).to.be.revertedWith("Access is forbidden");
      });
    });

    describe("bidAuction test", () => {
      beforeEach(async () => {
        await Marketplace.connect(account1).newAuction(
          LandPlot.address,
          [2],
          10000
        );
      });

      it("revert if there is not enough ether when bid auction", async () => {
        await Marketplace.connect(account2).bidAuction(0, { value: 1000 });
        await expect(
          Marketplace.connect(account3).bidAuction(0, { value: 1000 })
        ).to.be.revertedWith("Need more money");
      });

      it("revert if auction is canceled", async () => {
        await Marketplace.connect(account1).cancelAuction(0);
        await expect(
          Marketplace.connect(account2).bidAuction(0, { value: 1000 })
        ).to.be.revertedWith("Unavailable auction");
      });

      it("revert if time is up", async () => {
        await hre.network.provider.send("evm_increaseTime", [10000]);
        await hre.network.provider.send("evm_mine");
        await expect(
          Marketplace.connect(account2).bidAuction(0, { value: 1000 })
        ).to.be.revertedWith("Time is up");
      });

      it("revert if bidding is continuously", async () => {
        await Marketplace.connect(account2).bidAuction(0, { value: 1000 });
        await expect(
          Marketplace.connect(account2).bidAuction(0, { value: 2000 })
        ).to.be.revertedWith("Can't bid continuously");
      });

      it("check bidAuction function", async () => {
        await Marketplace.connect(account2).bidAuction(0, { value: 1000 });
        const auctionInfo = await Marketplace.auctionInfos(0);
        expect(auctionInfo.topBidder).to.equal(account2.address);
        expect(auctionInfo.topPrice).to.equal(1000);
      });
    });

    describe("endAuction test", () => {
      let balanceBeforeAuctionCreate;
      beforeEach(async () => {
        balanceBeforeAuctionCreate = await account1.getBalance();
        await Marketplace.connect(account1).newAuction(
          LandPlot.address,
          [2],
          10000
        );
      });

      it("revert if auction is still ongoing", async () => {
        await expect(
          Marketplace.connect(account1).endAuction(0)
        ).to.be.revertedWith("Auction is still ongoing");
      });

      it("revert if auction is ended", async () => {
        await hre.network.provider.send("evm_increaseTime", [10000]);
        await hre.network.provider.send("evm_mine");
        await Marketplace.connect(account1).endAuction(0);
        await expect(
          Marketplace.connect(account1).endAuction(0)
        ).to.be.revertedWith("Unavailable auction");
      });

      it("transfer ether after auction ends", async () => {
        const balanceBeforeBid = await account3.getBalance();
        await Marketplace.connect(account3).bidAuction(0, { value: 1001 });
        expect(await account3.getBalance()).to.equal(
          balanceBeforeBid.sub(1001)
        );
        await hre.network.provider.send("evm_increaseTime", [10000]);
        await hre.network.provider.send("evm_mine");
        await Marketplace.connect(account1).endAuction(0);
        expect(await account1.getBalance()).to.equal(
          balanceBeforeAuctionCreate.add(1001)
        );
        expect(await LandPlot.ownerOf(2)).to.equal(await account3.getAddress());
      });

      it("check endAuction function", async () => {
        await hre.network.provider.send("evm_increaseTime", [10000]);
        await hre.network.provider.send("evm_mine");
        await Marketplace.connect(account1).endAuction(0);
        const auctionInfo = await Marketplace.auctionInfos(0);
        expect(auctionInfo.oStatus).to.equal(auctionStatus.EXPIRED);
      });
    });

    describe("getTotalTokenCnt test", () => {
      it("check getTotalTokenCnt function", async () => {
        await Marketplace.connect(account1).newAuction(
          LandPlot.address,
          [2, 3],
          10000
        );
        expect(await Marketplace.connect(account2).getTotalTokenCnt()).to.equal(
          2
        );
      });
    });

    describe("getTokenId", () => {
      it("check getTokenId function after cancel auction", async () => {
        await Marketplace.connect(account1).newAuction(
          LandPlot.address,
          [2, 3],
          10000
        );
        await Marketplace.connect(account2).newAuction(
          LandPlot.address,
          [4],
          10000
        );
        await Marketplace.connect(account1).cancelAuction(0);
        const tokenInfo = await Marketplace.getTokenId(0);
        await expect(tokenInfo.tokenAddress).to.equal(LandPlot.address);
        await expect(tokenInfo.tokenId).to.equal(4);
        await expect(Marketplace.getTokenId(3)).to.be.revertedWith(
          "Invalid index"
        );
      });

      it("check getTokenId function after successful end auction", async () => {
        await Marketplace.connect(account1).newAuction(
          LandPlot.address,
          [2, 3],
          10000
        );
        await Marketplace.connect(account2).newAuction(
          LandPlot.address,
          [4],
          10000
        );
        await Marketplace.connect(account1).bidAuction(1, { value: 1000 });
        await hre.network.provider.send("evm_increaseTime", [10000]);
        await hre.network.provider.send("evm_mine");
        await Marketplace.connect(account2).endAuction(1);
        let tokenInfo = await Marketplace.getTokenId(0);
        await expect(tokenInfo.tokenAddress).to.equal(LandPlot.address);
        await expect(tokenInfo.tokenId).to.equal(2);
        tokenInfo = await Marketplace.getTokenId(1);
        await expect(tokenInfo.tokenAddress).to.equal(LandPlot.address);
        await expect(tokenInfo.tokenId).to.equal(3);
      });

      it("check getTokenId function after create auctions", async () => {
        await Marketplace.connect(account1).newAuction(
          LandPlot.address,
          [2, 3],
          10000
        );
        await Marketplace.connect(account2).newAuction(
          LandPlot.address,
          [4],
          10000
        );
        let tokenInfo = await Marketplace.getTokenId(0);
        await expect(tokenInfo.tokenAddress).to.equal(LandPlot.address);
        await expect(tokenInfo.tokenId).to.equal(2);
        tokenInfo = await Marketplace.getTokenId(1);
        await expect(tokenInfo.tokenAddress).to.equal(LandPlot.address);
        await expect(tokenInfo.tokenId).to.equal(3);
        tokenInfo = await Marketplace.getTokenId(2);
        await expect(tokenInfo.tokenAddress).to.equal(LandPlot.address);
        await expect(tokenInfo.tokenId).to.equal(4);
      });
    });

    describe("getAuctionInfo test", () => {
      beforeEach(async () => {
        await Marketplace.connect(account1).newAuction(
          LandPlot.address,
          [2, 3],
          10000
        );
      });

      it("revert if auctionInfoId is invalid", async () => {
        await expect(
          Marketplace.connect(account2).getAuctionInfo(2)
        ).to.be.revertedWith("Invalid auctionInfoId");
      });

      it("checkout getAuctionInfo function", async () => {
        const auctionInfo = await Marketplace.connect(account2).getAuctionInfo(
          0
        );
        expect(auctionInfo[0]).to.equal(await account1.getAddress());
        expect(auctionInfo[1][0].tokenAddress).to.equal(LandPlot.address);
        expect(auctionInfo[1][1].tokenAddress).to.equal(LandPlot.address);
        expect(auctionInfo[1][0].tokenId).to.equal(2);
        expect(auctionInfo[1][1].tokenId).to.equal(3);
        expect(auctionInfo[3]).to.equal(ZERO_ADDRESS);
        expect(auctionInfo[4]).to.equal(0);
        expect(auctionInfo[5]).to.equal(auctionStatus.STARTED);
      });
    });
  });

  describe("Purchase", () => {
    describe("newPurchase test", () => {
      it("check newPurchase function", async () => {
        const balanceBeforePurchaseCreate = await account1.getBalance();
        await Marketplace.connect(account1).newPurchase(
          LandPlot.address,
          [4],
          100000,
          { value: 10000 }
        );
        expect(await account1.getBalance()).to.equal(
          balanceBeforePurchaseCreate.sub(10000)
        );
        const purchaseInfo = await Marketplace.purchaseInfos(0);
        expect(purchaseInfo.purchaser).to.equal(await account1.getAddress());
        expect(purchaseInfo.tokenAddress).to.equal(LandPlot.address);
        expect(purchaseInfo.oStatus).to.equal(auctionStatus.STARTED);
        expect(purchaseInfo.tokenId).to.equal(4);
        expect(purchaseInfo.price).to.equal(10000);
      });

      it("revert if period is longer than a week", async () => {
        await expect(
          Marketplace.connect(account1).newPurchase(
            LandPlot.address,
            [4],
            10000000000000
          )
        ).to.be.revertedWith("Limit is a week");
      });
    });

    describe("cancelPurchase test", () => {
      let balanceBeforePurchaseCreate;
      beforeEach(async () => {
        balanceBeforePurchaseCreate = await account1.getBalance();
        await Marketplace.connect(account1).newPurchase(
          LandPlot.address,
          [4],
          10000,
          { value: 10000 }
        );
      });

      it("revert if cancel requester is not purchaser", async () => {
        await expect(
          Marketplace.connect(account2).cancelPurchase(0)
        ).to.be.revertedWith("Access is forbidden");
      });

      it("revert if purchaseInfoId is invalid", async () => {
        await expect(
          Marketplace.connect(account1).cancelPurchase(1)
        ).to.be.revertedWith("Invalid purchaseInfoId");
      });

      it("check cancelPurchase function", async () => {
        await Marketplace.connect(account1).cancelPurchase(0);
        expect(await account1.getBalance()).to.equal(
          balanceBeforePurchaseCreate
        );
        const purchaseInfo = await Marketplace.purchaseInfos(0);
        expect(purchaseInfo.oStatus).to.equal(auctionStatus.CANCELLED);
      });

      it("revert if purchase is invalid", async () => {
        await Marketplace.connect(account1).cancelPurchase(0);
        await expect(
          Marketplace.connect(account1).cancelPurchase(0)
        ).to.be.revertedWith("Unavailable purchase");
      });
    });

    describe("acceptPurchase test", () => {
      beforeEach(async () => {
        await Marketplace.connect(account1).newPurchase(
          LandPlot.address,
          [4],
          10000,
          { value: 10000 }
        );
      });

      it("check acceptPurchase function", async () => {
        const balanceBeforeAcceptPurchase = await account2.getBalance();
        await Marketplace.connect(account2).acceptPurchase(0);
        expect(await account2.getBalance()).to.equal(
          balanceBeforeAcceptPurchase.add(10000)
        );
        expect(await LandPlot.ownerOf(4)).to.equal(await account1.getAddress());
        const purchaseInfo = await Marketplace.purchaseInfos(0);
        expect(purchaseInfo.oStatus).to.equal(auctionStatus.FINISHED);
      });

      it("revert if time is up", async () => {
        await Marketplace.connect(account2).newPurchase(
          LandPlot.address,
          [3],
          10000
        );
        await hre.network.provider.send("evm_increaseTime", [10000]);
        await hre.network.provider.send("evm_mine");
        await expect(
          Marketplace.connect(account1).acceptPurchase(1)
        ).to.be.revertedWith("Time is up");
      });
    });

    describe("getPurchaseInfo test", () => {
      beforeEach(async () => {
        await Marketplace.connect(account1).newPurchase(
          LandPlot.address,
          [4],
          10000,
          { value: 10000 }
        );
      });

      it("check getPurchaseInfo function", async () => {
        const purchaseInfo = await Marketplace.connect(
          account2
        ).getPurchaseInfo(0);
        expect(purchaseInfo[0]).to.equal(await account1.getAddress());
        expect(purchaseInfo[1]).to.equal(LandPlot.address);
        expect(purchaseInfo[2]).to.equal(4);
        expect(purchaseInfo[3]).to.equal(10000);
        expect(purchaseInfo[5]).to.equal(auctionStatus.STARTED);
      });

      it("revert if purchaseInfoId is invalid", async () => {
        await expect(
          Marketplace.connect(account2).getPurchaseInfo(1)
        ).to.be.revertedWith("Invalid purchaseInfoId");
      });
    });
  });
});
