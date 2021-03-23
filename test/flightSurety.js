
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');
const e = require('express');

contract('Flight Surety Tests', async (accounts) => {

    var config;
    before('setup contract', async () => {
        config = await Test.Config(accounts);
        await config.flightSuretyData.authorizeContract(config.flightSuretyApp.address, {from: accounts[0]});
        await config.flightSuretyData.authorizeContract(config.owner, {from: accounts[0]});
    });

    /****************************************************************************************/
    /* Operations and Settings                                                              */
    /****************************************************************************************/

    it(`(multiparty) has correct initial isOperational() value`, async function () {

        // Get operating status
        let status = await config.flightSuretyData.isOperational.call();
        assert.equal(status, true, "Incorrect initial operating status value");

    });

    it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

        // Ensure that access is denied for non-Contract Owner account
        let accessDenied = false;
        try {
            await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
        }
        catch (e) {
            accessDenied = true;
        }
        assert.equal(accessDenied, true, "Access not restricted to Contract Owner");

    });

    it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

        // Ensure that access is allowed for Contract Owner account
        let accessDenied = false;
        try {
            await config.flightSuretyData.setOperatingStatus(false);
        }
        catch (e) {
            accessDenied = true;
        }
        assert.equal(accessDenied, false, "Access not restricted to Contract Owner");

    });

    it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

        await config.flightSuretyData.setOperatingStatus(false);

        let reverted = false;
        try {
            await config.flightSurety.setTestingMode(true);
        }
        catch (e) {
            reverted = true;
        }
        assert.equal(reverted, true, "Access not blocked for requireIsOperational");

        // Set it back for other tests to work
        await config.flightSuretyData.setOperatingStatus(true);

    });

    it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {

        // ARRANGE
        let newAirline = accounts[2];
        let newAirlineName = "accounts[2]";
        // ACT
        try {
            await config.flightSuretyApp.registerAirline(newAirlineName, newAirline, { from: config.firstAirline });
        }
        catch (e) {

        }
        let result = await config.flightSuretyData.isAirlineRegistered.call(newAirline);

        // ASSERT
        assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

    });

    it('(airline) firstAirline funding', async () => {
        // Declare and Initialize a variable for event
        var eventEmitted = false

        // Watch the emitted event Sold()
        config.flightSuretyApp.airlineFunded({}, function (error, result) {
            eventEmitted = true;
        });
        let foundingAmount = web3.utils.toWei("10", "ether");

        try {
            await config.flightSuretyApp.airlineFunding({ from: config.firstAirline, value: foundingAmount });
        } catch (error) {
            console.log(error);
        }

        let airlineInfo = await config.flightSuretyData.getAirlineInfo.call(config.firstAirline);
        // console.log(airlineInfo);
        // ASSERT
        assert.equal(eventEmitted, true, 'Invalid event emitted');
        assert.equal(airlineInfo[2], true, 'Airline funds failure');
    });

    it('(airline) can register an Airline using registerAirline() after funded', async () => {
        // ARRANGE
        let newAirline = accounts[2];
        let newAirlineName = "accounts[2]";
        // ACT
        try {
            let registerResult = await config.flightSuretyApp.registerAirline(newAirlineName, newAirline, { from: config.firstAirline });
            // console.log(registerResult);
        }
        catch (e) {
            console.log(e);
        }
        let result = await config.flightSuretyData.isAirlineRegistered.call(newAirline);

        // ASSERT
        assert.equal(result, true, "Airline should be able to register another airline if it has provided funding");

    });

    it('(airline) Multiparty Consensus', async () => {
        // ARRANGE
        let foundingAmount = web3.utils.toWei("10", "ether");
        let airline3 = accounts[3];
        let airlineName3 = "accounts[3]";
        let airline4 = accounts[4];
        let airlineName4 = "accounts[4]";
        let airline5 = accounts[5];
        let airlineName5 = "accounts[5]";

        // ACT
        try {
            let registerResult = await config.flightSuretyApp.registerAirline(airlineName3, airline3, { from: config.firstAirline });
            // console.log(registerResult);
            registerResult = await config.flightSuretyApp.registerAirline(airlineName4, airline4, { from: config.firstAirline });
            // console.log(registerResult);
            registerResult = await config.flightSuretyApp.registerAirline(airlineName5, airline5, { from: config.firstAirline });
            // console.log(registerResult);

        }
        catch (e) {
            console.log(e);
        }

        let notapproved = await config.flightSuretyData.isAirlineApproved.call(airline5);

        // ACT
        try {
            // funding first
            await config.flightSuretyApp.airlineFunding({ from: airline3, value: foundingAmount });
            await config.flightSuretyApp.airlineFunding({ from: airline4, value: foundingAmount });
            // approving
            let registerResult = await config.flightSuretyApp.registerAirline(airlineName5, airline5, { from: airline3 });
            // console.log(registerResult);
            registerResult = await config.flightSuretyApp.registerAirline(airlineName5, airline5, { from: airline4 });
            // console.log(registerResult);

        }
        catch (e) {
            console.log(e);
        }

        let approved = await config.flightSuretyData.isAirlineApproved.call(airline5);

        // ASSERT
        assert.equal(notapproved, false, "Airline[5] should be able to approving after passed multipatry consensus");
        assert.equal(approved, true, "Airline[5] should be approved after passed multipatry consensus");
    });
});
