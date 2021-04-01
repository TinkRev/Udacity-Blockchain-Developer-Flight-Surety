import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';
import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';

export default class Contract {
    constructor(network, callback) {

        let config = Config[network];
        // this.web3 = new Web3(new Web3.providers.HttpProvider(config.url));
        this. web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
        this.flightSuretyData = new this.web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
        this.initialize(config.appAddress, callback);
        this.owner = null;
        this.firstAirline = null;
        this.airlines = [];
        this.passengers = [];
        this.flightNumbers = new Map([["ND10000",new Date("2021-01-01")],["ND20000", new Date("2021-01-02")],["ND30000", new Date("2021-01-03")],["ND40000", new Date("2021-01-04")], ["ND50000", new Date("2021-01-05")]]);
    }

    initialize(appAdress, callback) {
        this.web3.eth.getAccounts((error, accts) => {
           
            this.owner = accts[0];
            this.web3.eth.defaultAccount = this.owner;
            this.firstAirline = accts[1];

            for(let index=1; index<5; index++){
                this.airlines.push(accts[index]);
            }

            // 0-19 are airlines and oracles
            for(let index=20; index<=25; index++) {
                this.passengers.push(accts[index]);
            }

            this.flightSuretyData.methods.authorizeContract(appAdress).send({from: this.owner}).then(result =>{
                console.log(result);
                this.flightSuretyData.methods.authorizeContract(this.owner).send({from: this.owner}).then(result =>{
                    console.log(result);
                    
                    let fundingAmount = Web3.utils.toWei("20", "ether");
                    this.initAirlineFund(this.firstAirline, fundingAmount).then(resule =>{
                        this.flightNumbers.forEach((value, key) =>
                        {
                            this.initFlight(this.airlines[0], key);
                        });
                        
                        for(let index=2; index<5; index++){
                            this.initAirlineRegister(this.firstAirline, accts[index]).then((result)=>{
                                this.initAirlineFund(accts[index], fundingAmount).then(fundedResult => {
                                    
                                });
                            });
                        }
                    });
                   


                });
            });

            var options = "";
            for(var index = 0 ; index < this.airlines.length; index++)
            {
            options += "<option>"+ this.airlines[index] +"</option>";
            }
            document.getElementById("ddairline").innerHTML = options;

            options = "";
            this.flightNumbers.forEach((value, key) =>
            {
                options += "<option value=\""+key+"\">"+ key +" departure at "+value.toString("yyyy-MM-dd HH:mm:ss")+"</option>";
            });
            document.getElementById("flight-number").innerHTML = options;

            options = "";
            for(var index = 0 ; index < this.passengers.length; index++)
            {
                options += "<option>"+ this.passengers[index] +"</option>";
            }
            document.getElementById("ddPassenger").innerHTML = options;

            
            callback();
        });
    
    }

    initAirlineRegister(airline, newAirline){
        // console.log("register: "+airline);
        return new Promise((resolve, result) =>{
            this.flightSuretyApp.methods.registerAirline(newAirline, newAirline)
            .send({ "from": airline, "gas": 9999999}, (error, result) => {
                // callback(error, payload);
                if(error) console.log(error);
                else 
                console.log("airline registered: "+ airline);
                
                resolve(true);
      
            });
            
        });
      }
      
    
    initAirlineFund(airline, amount){
        console.log("initAirlineFund: "+airline);
        this.web3.eth.getBalance(airline).then(console.log);
        return new Promise((resolve, result) =>{
            this.flightSuretyApp.methods.airlineFunding()
            .send({ "from": airline, "value": amount }, (error, result) =>{
                if(error) console.log(error)
                else
                    console.log("airline funded.");
                resolve(true);
            });
        });
    }

    initFlight(airline, flight){
        let flightTimestamp = Math.floor(this.flightNumbers.get(flight).getTime()/ 1000);

        console.log("initFlight: "+flight);
        this.web3.eth.getBalance(airline).then(console.log);
        return new Promise((resolve, result) =>{
            this.flightSuretyApp.methods.registerFlight(airline, flight, flightTimestamp)
            .send({ "from": airline}, (error, result) =>{
                if(error) console.log(error)
                else
                    console.log("flight added.");
                resolve(true);
            });
        });
    }

    isOperational(callback) {
       let self = this;
       self.flightSuretyApp.methods
            .isOperational()
            .call({ from: self.owner}, callback);
    }

    buy(passenger, amount, airline, flight, callback){
        
        let self = this;
        let flightTimestamp = Math.floor(this.flightNumbers.get(flight).getTime()/ 1000);
        let payload = {
            airline: airline,
            flight: flight,
            timestamp: flightTimestamp,
            from: passenger,
            value: amount
        } 
        self.flightSuretyApp.methods
            .buyInsurance(payload.airline, payload.flight, payload.timestamp)
            .send({ from: payload.from, value: payload.value, gas: 9999999}, (error, result) => {
                callback(error, payload);
            });
    }

    withdraw(passenger, callback){
        
        let self = this;
        let payload = {
            from: passenger
        } 
        self.flightSuretyApp.methods
            .withdraw()
            .send({ from: payload.from, gas: 9999999}, (error, result) => {
                
                callback(error, result);
            });
    }

    async fetchFlightStatus(airline, flight, callback) {
        let flightTimestamp = Math.floor(this.flightNumbers.get(flight).getTime()/ 1000);
        let self = this;
        let payload = {
            airline: airline,
            flight: flight,
            timestamp: flightTimestamp
        } 
        
        await self.flightSuretyApp.methods
            .fetchFlightStatus(payload.airline, payload.flight, payload.timestamp)
            .send({ from: self.owner}, (error, result) => {
                
                callback(error, payload);
                
            });
    }

}