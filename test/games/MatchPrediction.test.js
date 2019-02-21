const FutballCards = artifacts.require('FutballCards');
const MatchPrediction = artifacts.require('MatchPrediction');

const {BN, constants, expectEvent, shouldFail} = require('openzeppelin-test-helpers');

contract.only('Match Prediction game tests', ([_, creator, tokenOwner1, tokenOwner2, anyone, ...accounts]) => {

    context('construction', async function () {

        const baseURI = 'http://futball-cards';
        const State = {OPEN: new BN(0), HOME_WIN: new BN(1), AWAY_WIN: new BN(2), DRAW: new BN(3), CLOSED: new BN(4)};

        const _tokenId1 = new BN(0);
        const _tokenId2 = new BN(1);

        const that = this;

        before(async function () {
            that.futballCards = await FutballCards.new(baseURI, {from: creator});
            that.matchPrediction = await MatchPrediction.new(that.futballCards.address, {from: creator});

            // await this.futballCards.mintCard(1, 1, 1, 1, 1, 1, tokenOwner1, {from: creator});
            // await this.futballCards.setAttributes(_tokenId1, 10, 10, 10, 10, {from: creator});
            //
            // await this.futballCards.mintCard(2, 2, 2, 2, 2, 2, tokenOwner2, {from: creator});
            // await this.futballCards.setAttributes(_tokenId2, 5, 10, 20, 20, {from: creator});
            //
            // (await this.futballCards.totalCards()).should.be.bignumber.equal('2');
        });

        it('assert result as expected', async () => {

            // const futballCards = await FutballCards.new(baseURI, {from: creator});
            // const matchPrediction = await MatchPrediction.new(futballCards.address, {from: creator});
            const res = await that.matchPrediction.result();

            //await this.matchPrediction.resultGame(1);
            console.log(res.toString(10));
        });
    });

});
