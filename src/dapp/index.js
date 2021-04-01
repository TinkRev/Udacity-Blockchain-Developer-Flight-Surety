
import DOM from './dom';
import Contract from './contract';
import './flightsurety.css';


(async() => {

    let result = null;

    let insuraceFixedPayValue= 2; // ether

    DOM.elid('insuracePayValue').value= insuraceFixedPayValue;

    let contract = new Contract('localhost', () => {

        // Read transaction
        contract.isOperational((error, result) => {
            console.log(error,result);
            display('Operational Status', 'Check if contract is operational', [ { label: 'Operational Status', error: error, value: result} ]);
        });
    

        // User-submitted transaction
        DOM.elid('submit-oracle').addEventListener('click', () => {
            let airline = DOM.elid('ddairline').value;
            console.log(airline);
            let flight = DOM.elid('flight-number').value;
            // Write transaction
            contract.fetchFlightStatus(airline, flight, (error, result) => {
                display('Oracles', 'Trigger oracles', [ { label: 'Fetch Flight Status', error: error, value: result.flight + ' ' + result.timestamp} ]);
            });

        })

        // User-submitted transaction
        DOM.elid('buyInsurance').addEventListener('click', () => {
            let airline = DOM.elid('ddairline').value;
            console.log(airline);
            let flight = DOM.elid('flight-number').value;
            let passenger = DOM.elid('ddPassenger').value;
            // Write transaction
            contract.buy(passenger, insuraceFixedPayValue, airline, flight, (error, result) => {
                display('Buy', 'Trigger Buy', [ { label: 'Passenger buy insurance', error: error, value: result.from + ' ' + result.value} ]);
            });

        })
        
        // User-submitted transaction
        DOM.elid('withDraw').addEventListener('click', () => {
            let passenger = DOM.elid('ddPassenger').value;
            // Write transaction
            contract.withdraw(passenger, (error, result) => {
                display('Withdarw', 'Trigger Withdarw', [ { label: 'Passenger withdraw', error: error, value: result} ]);
            });

        })
        
    
    });
    
    
    contract.flightSuretyApp.events.CanWithdraw()
    .on('data', async function(event){
        let val = "Airline: "+ event.returnValues.airline+ ", Flight: "+ event.returnValues.flight+ ", Reason: "+ (event.returnValues.statusCode == '20'? "Late": "Technical")
        display('Passenger Repayment', 'Airline fault', [ { label: 'Process Flight Status', error: '', value: val} ]);

        console.log(event.returnValues);
        // Do something here
    })
    .on('error', console.error);

    contract.flightSuretyApp.events.Paid()
    .on('data', async function(event){
        let val = "Passenger: "+ event.returnValues.passenger+ ", Received amount: "+ event.returnValues.balance
        display('Passenger Withdraw', 'Passenger received amount of claim', [ { label: 'Withdraw', error: '', value: val} ]);

        console.log(event.returnValues);
    });

})();


function display(title, description, results) {
    let displayDiv = DOM.elid("display-wrapper");
    let section = DOM.section();
    section.appendChild(DOM.h2(title));
    section.appendChild(DOM.h5(description));
    results.map((result) => {
        let row = section.appendChild(DOM.div({className:'row'}));
        row.appendChild(DOM.div({className: 'col-sm-4 field'}, result.label));
        row.appendChild(DOM.div({className: 'col-sm-8 field-value'}, result.error ? String(result.error) : String(result.value)));
        section.appendChild(row);
    })
    displayDiv.prepend(section);

}







