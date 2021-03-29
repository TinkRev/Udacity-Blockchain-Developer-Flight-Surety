import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';
import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';


let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));

let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
let flightSuretyData = new web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);
web3.eth.getBalance(config.dataAddress).then(console.log)
web3.eth.getBalance(config.appAddress).then(console.log)
let owner = null;
let firstAirline = null;
let fundingAmount = Web3.utils.toWei("20", "ether");

// FLIGHT_STATUS_CODE: Unknown (0), On Time (10) or Late Airline (20), Late Weather (30), Late Technical (40), or Late Other (50)
let FLIGHT_STATUS_CODE = [0, 10, 20, 30, 40, 50];
let SIMULATE_SERVER_COUNT = 20;
let simulOraclePool = new Map(); // address pool

function getRandomInt(max) {
  return Math.floor(Math.random() * Math.floor(max));
}


web3.eth.getAccounts().then(function(acc){
  owner = acc[0];
  web3.eth.defaultAccount = owner;

  for(let index=1; index<=SIMULATE_SERVER_COUNT; index++){
    simulOraclePool.set(acc[index],[]);
  }
});

flightSuretyApp.methods.REGISTRATION_FEE().call().then(fee=>{
    console.log("oracle register fee = " + fee);
    //accounts will be an array with all accounts that comes from your Ethereum provider
    
    simulOraclePool.forEach((value, key)=>{
      // register server
      registerOracle(key, fee).then(result =>{
        console.log("server registered which address = "+ key + ", indexs = "+ result);
        simulOraclePool.set(key,result);
      });
    });
});




function registerOracle(key, fee){
  return new Promise((reslove, result) =>{
    flightSuretyApp.methods.registerOracle().send({
      "from": key,
      "value": fee,
      "gas": 6721975,
      "gasPrice": 100000000000
    }).then(result => {
      // console.log(result);
      //oracle created;
      flightSuretyApp.methods.getMyIndexes().call({
          "from": key
        }).then(indexs => {
          // console.log(indexs);
          reslove(indexs);
        });
      }).catch(err => {
        console.log("error in flightSuretyApp.methods.getMyIndexes(): ");
        console.log(err);
          // oracle errored
      })
  });
}

flightSuretyApp.events.OracleRequest({
    fromBlock: 0
  }, function (error, event) {
    if (error) console.log(error)
    console.log(event.returnValues.index);
    console.log(event.returnValues.airline);
    console.log(event.returnValues.flight);
    console.log(event.returnValues.timestamp);
    submitResponseToContract(event.returnValues.index, event.returnValues.airline, event.returnValues.flight, event.returnValues.timestamp);
});

function submitResponseToContract(index, airline, flight, timestamp){
  console.log('start submitResponseToContract, parameter: '+index+", "+airline+", "+flight+", "+timestamp);
  simulOraclePool.forEach((value, key) => {
    // console.log('show value'+ value)
    if(value.includes(index)){
      // submit response to contract
      console.log("do submit response to contract");
      var code = FLIGHT_STATUS_CODE[getRandomInt(FLIGHT_STATUS_CODE.length)];
      flightSuretyApp.methods.submitOracleResponse(index, airline, flight, timestamp, code).send({
        "from": key,
        "gas": 9999999,
        "gasPrice": 100000000000
      });
    }
  });
}

flightSuretyApp.events.OracleReport(function (error, event) {
  if (error) console.log(error)
  console.log("oracle report");
  console.log(event);
});

flightSuretyApp.events.CanWithdraw(function (error, event) {
  if (error) console.log(error)
  console.log("CanWithdraw");
  console.log(event);
});

flightSuretyApp.events.Paid(function (error, event) {
  if (error) console.log(error)
  console.log("Paid");
  console.log(event);
});

const app = express();
app.get('/api', (req, res) => {
    res.send({
      message: 'An API for use with your Dapp!'
    })
})

export default app;


