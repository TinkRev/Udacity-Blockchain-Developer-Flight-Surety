const FlightSuretyApp = artifacts.require("FlightSuretyApp");
const FlightSuretyData = artifacts.require("FlightSuretyData");
const fs = require('fs');


module.exports = function(deployer) {

    let firstAirline = '0xd10c00c953b3d4de6f2ad234c7460a65de1d2b24'; // from truffle console account[1]
    // firstAirline = '0x40e056B52D68b13ce04a571a287DC68332e12399'; // from ganache , {value: 20000000000000000000}
    let firstAirlineName = "UDACITY";
    deployer.deploy(FlightSuretyData, firstAirlineName, firstAirline, {value: 20000000000000000000})
    .then(() => {
        return deployer.deploy(FlightSuretyApp, FlightSuretyData.address, {value: 20000000000000000000})
                .then(() => {
                    
                    let config = {
                        localhost: {
                            url: 'http://localhost:9545',
                            dataAddress: FlightSuretyData.address,
                            appAddress: FlightSuretyApp.address
                        }
                    }
                    
                    fs.writeFileSync(__dirname + '/../src/dapp/config.json',JSON.stringify(config, null, '\t'), 'utf-8');
                    fs.writeFileSync(__dirname + '/../src/server/config.json',JSON.stringify(config, null, '\t'), 'utf-8');
                });
    });
}