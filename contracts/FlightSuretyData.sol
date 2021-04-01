pragma solidity >=0.4.24;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner; // Account used to deploy contract
    bool private operational = true; // Blocks all state changes throughout the contract if false
    mapping(address => uint256) private authorizedContracts;
    mapping(address => uint256) private fundedInfo;
    uint private fundedBalance = 0;

    struct Airline {
        bool isApproved; // passed multi consensus
        bool isRegistered;
        address updator;
        bool isFunded; // can participate contact
        address airlineAddress;
    }
    uint256 private _airlineCounter;
    mapping(address => Airline) private airlines; // keep airlines
    
    uint multiCallCounter = 0;
    mapping(uint => address) private multiCalls;

    struct Passenger{
        address passengerAddress;
        uint amount;
    }

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        address updator;
        address airline;
        mapping(address => uint) passengerInsured;
        uint passengerInsuredCounter;
        mapping(uint => Passenger) passengerInsuredInfos;
    }
    mapping(bytes32 => Flight) private flights; // keep flights

    mapping(address => Passenger) private payOutToPassenger;
    mapping(uint => address) private payOutKeys;
    uint private payOutCounter;


    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    /**
     * @dev Constructor
     *      The deploying account becomes contractOwner
     */
    constructor(address firstAirline) public payable {
        contractOwner = msg.sender;
        _airlineCounter = 0;
        _registerAirline(msg.sender, firstAirline, true);
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
     * @dev Modifier that requires the "operational" boolean variable to be "true"
     *      This is used on all state changing functions to pause the contract in
     *      the event there is an issue that needs to be fixed
     */
    modifier requireIsOperational() {
        require(operational, "Contract is currently not operational");
        _; // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
     * @dev Modifier that requires the "ContractOwner" account to be the function caller
     */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireIsCallerAuthorized() {
        require(authorizedContracts[msg.sender] == 1,"Caller is not allowed contract");
        _;
    }

    modifier requireAirlineRegistered(address airline) {
        require(airlines[airline].isRegistered,"Airline should register first");
        _;
    }

    modifier requireAirlineNotRegistered(address airline) {
        require(!airlines[airline].isRegistered,"Airline should not register again");
        _;
    }

    modifier requireAirlineFunded(address airline) {
        require(airlines[airline].isFunded, "Airline should fund first");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
     * @dev Get operating status of contract
     *
     * @return A bool that is the current operating status
     */

    function isOperational() public view returns (bool) {
        return operational;
    }

    /**
     * @dev Sets contract operations on/off
     *
     * When operational mode is disabled, all write transactions except for this one will fail
     */

    function setOperatingStatus(bool mode) external requireContractOwner {
        operational = mode;
    }

    function authorizeContract(address contractAddress) external requireContractOwner
    {
        authorizedContracts[contractAddress] = 1;
    }

    function deauthorizeContract(address contractAddress) external requireContractOwner
    {
        delete authorizedContracts[contractAddress];
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /**
     * @dev Add an airline to the registration queue
     *      Can only be called from FlightSuretyApp contract
     *
     */

    function addAirline(uint minAirlineCounter,address airline, address newAirline) external
        requireIsOperational requireIsCallerAuthorized requireAirlineFunded(airline) returns (bool waitForVoting){
        // do register
        bool _isApproved=false;
        if(_airlineCounter < minAirlineCounter){
            _isApproved = true;
        }else{
            _isApproved = false;
            multiCalls[multiCallCounter] = airline;
            multiCallCounter = multiCallCounter.add(1);
        }
        _registerAirline(airline, newAirline, _isApproved);

        waitForVoting = _isApproved;
        return waitForVoting;
    }

    function vote(address airline, address newAirline) external 
        requireIsOperational returns(uint voteCounter)
    {
        require(!airlines[newAirline].isApproved, "Airline had been approved");

        bool _isApproved=false;
        // Multiparty Consensus >=50%
        // do voting
        // update M
        uint M = _airlineCounter;

        // do approve
        bool isDuplicate = false;
        for (uint256 c = 0; c < multiCallCounter; c++) {
            if (multiCalls[c] == airline) {
                isDuplicate = true;
                break;
            }
        }

        require(!isDuplicate, "Caller has already called this function.");

        multiCalls[multiCallCounter] = airline;
        multiCallCounter = multiCallCounter.add(1);
    
        if (multiCallCounter * 2 >= M) {
            _isApproved = true;
            multiCallCounter = 0;
            _updateAirlineApproveInfo(airline, newAirline, _isApproved);
        }else{
            _isApproved = false;
        }

        voteCounter = multiCallCounter;
        return voteCounter;
    }

    function _registerAirline(address updator, address newAirline, bool isApproved) private
        requireAirlineNotRegistered(newAirline) 
    {
        airlines[newAirline] = Airline({
            isApproved: isApproved,
            isRegistered: true,
            updator: updator,
            isFunded: false,
            airlineAddress: newAirline
        });
        _airlineCounter = _airlineCounter.add(1);
    }

    function _updateAirlineApproveInfo(address updator, address airline, bool isApproved) internal 
        requireAirlineRegistered(airline)
    {
        airlines[airline].isApproved = isApproved;
        airlines[airline].updator = updator;
    }

    function getAirlineRegisteredCounter() external view
        requireIsOperational requireIsCallerAuthorized 
        returns (uint256)
    {
        return _airlineCounter;
    }


    function isAirlineRegistered(address airline) external view 
        requireIsOperational requireIsCallerAuthorized 
        returns (bool) 
    {
        return airlines[airline].isRegistered;
    }

    function isAirlineApproved(address airline) external view
        requireIsOperational requireIsCallerAuthorized 
        returns (bool) 
    {
        return airlines[airline].isApproved;
    }

    function isAirlineFunded(address airline) external
        requireIsOperational requireIsCallerAuthorized view 
        returns (bool) 
    {
        return airlines[airline].isFunded;
    }

    function getAirlineInfo(address airline)
        external view requireIsOperational requireIsCallerAuthorized
        returns (
            bool isRegistered,
            address updator,
            bool isFunded,
            address airlineAddress
        )
    {
        Airline memory element = airlines[airline];
        isRegistered = element.isRegistered;
        updator = element.updator;
        isFunded = element.isFunded;
        airlineAddress = element.airlineAddress;
        return (
            isRegistered,
            updator,
            isFunded,
            airlineAddress
        );
    }



    function addFlight(address updator, address airline, string calldata flight, uint256 timestamp) external 
        requireIsOperational requireIsCallerAuthorized()
    {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        flights[flightKey] = Flight({
            isRegistered:true,
            statusCode: 0,
            updator: updator,
            airline: airline,
            passengerInsuredCounter: 0
        });

    }

    /**
     * @dev Buy insurance for a flight
     *
     */

    function buy(address passenger, uint amount, address airline, string calldata flight, uint256 timestamp) external payable 
        requireIsOperational
    {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        uint counter = flights[flightKey].passengerInsuredCounter;
        
        flights[flightKey].passengerInsuredInfos[counter] = Passenger({
            passengerAddress: passenger,
            amount: amount
        });
        flights[flightKey].passengerInsuredCounter = counter.add(1);
        flights[flightKey].passengerInsured[passenger] = 1;

    }

    /**
     *  @dev Credits payouts to insurees
     */
    function creditInsurees(address airline, string calldata flight, uint256 timestamp) external 
        requireIsOperational
    {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);
        uint counter = flights[flightKey].passengerInsuredCounter;
        for(uint index=0; index< counter; index++){
            address passenger = flights[flightKey].passengerInsuredInfos[index].passengerAddress;
            uint amount = flights[flightKey].passengerInsuredInfos[index].amount;
            flights[flightKey].passengerInsured[passenger] = 0;
            flights[flightKey].passengerInsuredInfos[index].amount = 0;
            flights[flightKey].passengerInsuredCounter = flights[flightKey].passengerInsuredCounter.sub(1);
            payOutToPassenger[passenger].amount = payOutToPassenger[passenger].amount.add(amount.mul(3).div(2));
            payOutKeys[payOutCounter] = passenger;
            payOutCounter = payOutCounter.add(1);
        }

    }

    // function getPayOutInfos() external view returns(mapping(uint => address), uint){
    //     return (payOutToPassenger, payOutCounter);
    // }

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
     */
    function pay(address passenger) external payable requireIsOperational returns (uint balance){
        require(payOutToPassenger[passenger].amount>0, "nothing need to pay");
        balance = payOutToPassenger[passenger].amount;
        delete payOutToPassenger[passenger];
        address(uint160(passenger)).transfer(balance);

        return balance;
    }

    /**
     * @dev Initial funding for the insurance. Unless there are too many delayed flights
     *      resulting in insurance payouts, the contract should be self-sustaining
     *
     */

    function fund(address airline, uint amount) public payable
        requireIsOperational requireAirlineRegistered(airline)
    {
        // can fund more than once
        airlines[airline].updator = airline;
        airlines[airline].isFunded = true;
        fundedInfo[airline] = fundedInfo[airline].add(amount);
        fundedBalance = fundedBalance.add(msg.value);
        
    }

    function getFlightKey(
        address airline,
        string memory flight,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
     * @dev Fallback function for funding smart contract.
     *
     */
    function() external payable {
        // fundedBalance = fundedBalance.add(msg.value);
    }
}
