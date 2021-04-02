pragma solidity >=0.4.24;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    FlightSuretyData flightSuretyData;
    uint private constant FUNDING_THRESHOLD = 10 ether;
    
    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    address private contractOwner; // Account used to deploy contract

    
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
        // Modify to call data contract's status
        require(flightSuretyData.isOperational(), "Contract is currently not operational");
        _; // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
     * @dev Modifier that requires the "ContractOwner" account to be the function caller
     */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
     * @dev Contract constructor
     *
     */
    constructor(address dataContract) public payable {
        contractOwner = msg.sender;
        // address payable payableDataContract= address(uint160(dataContract));
        flightSuretyData = FlightSuretyData(dataContract);

        // address(this).transfer(msg.value);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() public view returns (bool) {
        return flightSuretyData.isOperational(); // Modify to call data contract's status
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    event AirlineWaitForApproving(address newAirline);
    event AirlineRegistered(address newAirline);
    /**
     * @dev Add an airline to the registration queue
     *
     */
    function registerAirline(address newAirline) public requireIsOperational returns (uint256 votes)
    {
        uint minAirlineAounter = 4;
        bool isRegistered = flightSuretyData.isAirlineRegistered(newAirline);
        if(isRegistered){
            bool isApproved = flightSuretyData.isAirlineApproved(newAirline);
            require(!isApproved, "Airline has been registered and approved");
            votes = flightSuretyData.vote(msg.sender, newAirline);
            if(votes >= minAirlineAounter){
                emit AirlineRegistered(newAirline);
            }
        }else{
            bool _isApproved = flightSuretyData.addAirline(minAirlineAounter, msg.sender, newAirline);
            if(_isApproved){
                votes = 0;
            }else{
                emit AirlineWaitForApproving(newAirline);
                votes = 1;
            }
        }

        return (votes);
    }

    event AirlineFunded();
    function airlineFunding() public requireIsOperational payable{
        require(msg.value >= FUNDING_THRESHOLD,"Funding 10 ether to participate contract");

        // https://docs.soliditylang.org/en/v0.5.16/control-structures.html?highlight=address%20function%20value#external-function-calls
        // vm exception could not slove.
        // flightSuretyData.fund.value(FUNDING_THRESHOLD)(msg.sender,FUNDING_THRESHOLD);
        // address(uint160(address(flightSuretyData))).transfer(msg.value);
        (bool success, bytes memory result) = address(uint160(address(flightSuretyData))).call.value(FUNDING_THRESHOLD)("");
        require(success, "call data contract failure");
        flightSuretyData.fund(msg.sender,msg.value);
        emit AirlineFunded();
    }

    /**
     * @dev Register a future flight for insuring.
     *
     */

    function registerFlight(address airline, string calldata flight, uint256 timestamp) external requireIsOperational{
        flightSuretyData.addFlight(msg.sender, airline, flight, timestamp);
    }

    function buyInsurance(address airline, string calldata flight, uint256 timestamp) external requireIsOperational payable{
        (bool success, bytes memory result) = address(uint160(address(flightSuretyData))).call.value(msg.value)("");
        require(success, "call data contract failure");
        flightSuretyData.buy(msg.sender, msg.value, airline, flight, timestamp);
    }


    event CanWithdraw(address airline, string flight, uint8 statusCode);
    /**
     * @dev Called after oracle has updated flight status
     *
     */
    function processFlightStatus(
        address airline,
        string memory flight,
        uint256 timestamp,
        uint8 statusCode
    ) internal {
        if(statusCode == STATUS_CODE_LATE_AIRLINE 
            || statusCode == STATUS_CODE_LATE_TECHNICAL){
                flightSuretyData.creditInsurees(airline, flight, timestamp);
                emit CanWithdraw(airline, flight, statusCode);
            }
    }

    event Paid(address passenger, uint balance);
    function withdraw() external requireIsOperational payable returns (address passenger, uint balance){
        passenger = msg.sender;
        balance = flightSuretyData.pay(passenger);
        emit Paid(passenger, balance);
        return (passenger, balance);
    }

    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus(
        address airline,
        string calldata flight,
        uint256 timestamp
    ) external requireIsOperational {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(
            abi.encodePacked(index, airline, flight, timestamp)
        );
        oracleResponses[key] = ResponseInfo({
            requester: msg.sender,
            isOpen: true
        });

        emit OracleRequest(index, airline, flight, timestamp);
    }

    // region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;

    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester; // Account that requested status
        bool isOpen; // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses; // Mapping key is the status code reported
        // This lets us group responses and identify
        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(
        address airline,
        string flight,
        uint256 timestamp,
        uint8 status
    );

    event OracleReport(
        address airline,
        string flight,
        uint256 timestamp,
        uint8 status
    );

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(
        uint8 index,
        address airline,
        string flight,
        uint256 timestamp
    );

    // Register an oracle with the contract
    function registerOracle() external requireIsOperational payable {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({isRegistered: true, indexes: indexes});
    }

    function getMyIndexes() external requireIsOperational view returns (uint8[3] memory) {
        require(
            oracles[msg.sender].isRegistered,
            "Not registered as an oracle"
        );

        return oracles[msg.sender].indexes;
    }

    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse(
        uint8 index,
        address airline,
        string calldata flight,
        uint256 timestamp,
        uint8 statusCode
    ) external requireIsOperational {
        require(
            (oracles[msg.sender].indexes[0] == index) ||
                (oracles[msg.sender].indexes[1] == index) ||
                (oracles[msg.sender].indexes[2] == index),
            "Index does not match oracle request"
        );

        bytes32 key = keccak256(
            abi.encodePacked(index, airline, flight, timestamp)
        );
        require(
            oracleResponses[key].isOpen,
            "Flight or timestamp do not match oracle request"
        );

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {
            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }

    // function getFlightKey(
    //     address airline,
    //     string memory flight,
    //     uint256 timestamp
    // ) internal pure returns (bytes32) {
    //     return keccak256(abi.encodePacked(airline, flight, timestamp));
    // }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes(address account) internal returns (uint8[3] memory) {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);

        indexes[1] = indexes[0];
        while (indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while ((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex(address account) internal returns (uint8) {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(
            uint256(
                keccak256(
                    abi.encodePacked(blockhash(block.number - nonce++), account)
                )
            ) % maxValue
        );

        if (nonce > 250) {
            nonce = 0; // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

    // endregion

}

contract FlightSuretyData {
    function isOperational() public view returns (bool);
    function authorizeContract(address contractAddress) external;
    function addAirline(uint minAirlineCounter,address airline, address newAirline) external returns (bool waitForVoting);
    function vote(address airline, address newAirline) external returns(uint voteCounter);
    function isAirlineRegistered(address airline) external view returns (bool);
    function isAirlineApproved(address airline) external view returns (bool);
    function getAirlineRegisteredCounter() external view returns (uint256);
    function fund(address airline, uint amount) public payable;
    function addFlight(address updator, address airline, string calldata flight, uint256 timestamp) external;
    function buy(address passenger, uint amount, address airline, string calldata flight, uint256 timestamp) external payable;
    function creditInsurees(address airline, string calldata flight, uint256 timestamp) external;
    function pay(address passenger) external payable returns (uint balance);
}