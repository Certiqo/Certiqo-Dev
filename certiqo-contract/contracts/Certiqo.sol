pragma solidity ^0.6.12;

// SPDX-License-Identifier: MIT

contract Certiqo {
    
    /*******************  Memory declaration ****************************/
    
    bool locked = false;                            // lock for Reentrancy guard
    bytes32 filehash;                       // keccak256 hash of External data
    
    enum State{
      Approved,         //0
      Hold,             //1
      Manufactured,     //2
      MftrDispatched,   //3
      DistrReceived,    //4
      DistrDispatched,  //5
      PharReceived,     //6
      Dispensed         //7
    }
    
    enum role{
        Default,        //0                 // Default role used for check non-membership
        Manufacturer,   //1
        Distributor,    //2
        Pharmacist,     //3
        FDA             //4
    }
    
    struct Item{
        State state;
        address payable owner;
        uint256 price;
    }
    
    mapping (uint => Item) directory;      // directory of drug NDC uint => its current state
    mapping (address => role) roles;        // stores roles of each registered user
    
    /********************* Events & Modifiers ***************************/
    
    event Registered(address member);
    event Unregistered(address member);
    event Approved(uint _ndc);
    event Hold(uint _ndc);
    event Manufactured(uint _ndc);
    event MftrDispatched(uint _ndc);
    event DistrReceived(uint _ndc);
    event DistrDispatched(uint _ndc);
    event PharReceived(uint _ndc);
    event Dispensed(uint _ndc);
    
    modifier onlyFDA{ 
        require(roles[msg.sender] == role.FDA, "Access Denied, only FDA can perform this operation !");
        _;
    }
    
    modifier onlyManufacturer{ 
        require(roles[msg.sender] == role.Manufacturer, "Access Denied, only Manufacturer can perform this operation !");
        _;
    }
    
    modifier onlyDistributor{ 
        require(roles[msg.sender] == role.Distributor, "Access Denied, only Distributor can perform this operation !");
        _;
    }
    
    modifier onlyPharmacist{ 
        require(roles[msg.sender] == role.Pharmacist, "Access Denied, only Pharmacist can perform this operation !");
        _;
    }
    
    modifier isAuthentic(bytes32 _hash){
        require(filehash == _hash, "File hash error: External data corrupted !");
        _;
    }
    
    modifier isMember(address member){ 
        require(roles[member] == role.FDA || roles[member] == role.Manufacturer || roles[member] == role.Distributor || roles[member] == role.Pharmacist,
                "Operation Failed: Not a member of Certiqo !");
        _;
    }
    
    modifier isApproved(uint _ndc) {
        require(directory[_ndc].state == State.Approved,"Drug not approved!");
        _;
    }
    
    modifier isManufactured(uint _ndc) {
        require(directory[_ndc].state == State.Manufactured,"Drug not manufactured!");
        _;
    }
    
    modifier isMftrDispatched(uint _ndc) {
        require(directory[_ndc].state == State.MftrDispatched,"Drug not dispatched by manufacturer!");
        _;
    }
    
    modifier isDistrReceived(uint _ndc) {
        require(directory[_ndc].state == State.DistrReceived,"Drug not received by distributor!");
        _;
    }
    
    modifier isDistrDispatched(uint _ndc) {
        require(directory[_ndc].state == State.DistrDispatched,"Drug not disptached by distributor!");
        _;
    }
    
    modifier isPharReceived(uint _ndc) {
        require(directory[_ndc].state == State.PharReceived,"Drug not received by pharmacist!");
        _;
    }
    
    
    /********************************** Functions ********************************************/
    
            /************* only FDA *************************/
    constructor(bytes32 hash) public { 
        
        /*
            Input: None
            Return: None
            Operation: Assign contract deployer as the FDA authority and initialize filehash
        */
        
        filehash = hash;
    }
    
    function register(address member, role R) public {
        
        /*
            Input: member (address of the new member), role (type of the member 0 to 4)
            Return: None
            Operation: Register the new member with the specified role in the 'roles' mapping
        */
        
        if(roles[member] == role.FDA || roles[member] == role.Manufacturer || roles[member] == role.Distributor || roles[member] == role.Pharmacist){
            revert("User already registered");
        }
        roles[member] = R;
        emit Registered(member);
    }
    
    function unregister(address member) public isMember(member) {
        
        /*
            Input: member (address of the member to unregister)
            Return: None
            Operation: Unregister the member with the specified address and purge entry in the 'roles' mapping
        */
        
        delete roles[member];
        emit Unregistered(member);
    }
    
    function approveDrug(uint _ndc, bytes32 _hash) public isAuthentic(_hash) onlyFDA {
        
        /*
            Input: _ndc (10 digit National Drug Code [NDC] generated by the Manufacturer)
            Return: None
            Operation: change the status of a drug to 'Approved'
        */
        
        directory[_ndc].state = State.Approved;
        emit Approved(_ndc);
    }
    
    function suspendDrug(uint _ndc, bytes32 _hash) public isAuthentic(_hash) onlyFDA {
        
        /*
            Input: _ndc (10 digit National Drug Code [NDC] generated by the Manufacturer)
            Return: None
            Operation: change the status of a drug to 'Hold'
        */
        
        directory[_ndc].state = State.Hold;
        emit Hold(_ndc);
    }
    
         /************** only Manufacturer *************************/
    
    function manufactureDrug(uint _ndc, bytes32 _hash) public isAuthentic(_hash) onlyManufacturer isApproved(_ndc) {
          
        /*
            Input: _ndc (10 digit National Drug Code [NDC] generated by the Manufacturer)
            Return: None
            Operation: change the status of a drug to 'Manufactured' and set the current owner address
        */
        
        directory[_ndc].state = State.Manufactured;
        directory[_ndc].owner = msg.sender;
        emit Manufactured(_ndc);
    }
    
    function dispatchToDistributor(uint _ndc, uint256 _price, bytes32 _hash) public 
        isAuthentic(_hash) onlyManufacturer isManufactured(_ndc) 
    {
        
        /*
            Input: _ndc (10 digit National Drug Code [NDC] generated by the Manufacturer)
            Return: None
            Operation: change the status of a drug to 'MftrDispatched' and set the sale price of drug
        */
        
        directory[_ndc].state = State.MftrDispatched;
        directory[_ndc].price = _price;
        emit MftrDispatched(_ndc);
    }
    
            /************** only Distributor *************************/
            
    function receiveFromManuacturer(uint _ndc, bytes32 _hash) public 
        isAuthentic(_hash) onlyDistributor isMftrDispatched(_ndc) payable
    {
        
        /*
            Input: _ndc (10 digit National Drug Code [NDC] generated by the Manufacturer), msg.value (Price of drug set by owner)
            Return: None
            Operation: change the status of a drug to 'DistrReceived' and transfer the price of drug to its current owner address
        */
        
        address sender = msg.sender;
        address payable _receiver = directory[_ndc].owner;
        require(sender.balance >= msg.value, "Not Enough Balance");                                      // check balance
        require(directory[_ndc].price == msg.value, "Full price of drug was not entered as Value !!");  // verify transfer amount
        
        // Initiate transfer
        require(!locked, "Reentrant call detected!");
        locked = true;
            bool success = false;
            (success, ) = _receiver.call{value: msg.value}("");
            require(success, "Transfer failed.");
            directory[_ndc].state = State.DistrReceived;
            directory[_ndc].owner = msg.sender;
        locked = false;
        emit DistrReceived(_ndc);
    }
    
    function dispatchToPharmacist(uint _ndc, uint256 _price, bytes32 _hash) public 
        isAuthentic(_hash) onlyDistributor isDistrReceived(_ndc) payable 
    {
        
        /*
            Input: _ndc (10 digit National Drug Code [NDC] generated by the Manufacturer)
            Return: None
            Operation: change the status of a drug to 'DistrDispatched' and set the sale price of drug
        */
        
        directory[_ndc].state = State.DistrDispatched;
        directory[_ndc].price = _price;
        emit DistrDispatched(_ndc);
    }
    
            /************* only Pharmacist *************************/
    
    function receiveFromDistributor(uint _ndc, bytes32 _hash) public 
        isAuthentic(_hash) onlyPharmacist isDistrDispatched(_ndc) payable 
    {
        
        /*
            Input: _ndc (10 digit National Drug Code [NDC] generated by the Manufacturer), msg.value (Price of drug set by owner)
            Return: None
            Operation: change the status of a drug to 'PharReceived' and transfer the price of drug to its current owner address
        */
        
        address sender = msg.sender;
        address payable _receiver = directory[_ndc].owner;
        require(sender.balance >= msg.value, "Not Enough Balance");                                      // check balance
        require(directory[_ndc].price == msg.value, "Full price of drug was not entered as Value !!");  // verify transfer amount
        
        // Initiate transfer
        require(!locked, "Reentrant call detected!");
        locked = true;
            bool success = false;
            (success, ) = _receiver.call{value: msg.value}("");
            require(success, "Transfer failed.");
            directory[_ndc].state = State.PharReceived;
            directory[_ndc].owner = msg.sender;
        locked = false;
        emit PharReceived(_ndc);
    }
    
    function dispenseToConsumer(uint _ndc, uint256 _price, bytes32 _hash) public 
        isAuthentic(_hash) onlyPharmacist isPharReceived(_ndc) payable 
    {
        
        /*
            Input: _ndc (10 digit National Drug Code [NDC] generated by the Manufacturer)
            Return: None
            Operation: change the status of a drug to 'Dispensed' and set the sale price of drug
        */
        
        directory[_ndc].state = State.Dispensed;
        directory[_ndc].price = _price;
        emit Dispensed(_ndc);
    }
    
            /******************* Public *************************/
    
    function verifyDrug(uint _ndc, address m_address, address d_address, address p_address) public view returns(uint statusCode) { 
        
        /*
            Input: 
                _ndc (10 digit National Drug Code [NDC] generated by the Manufacturer),
                m_address (Manufacturer address),
                d_address (d_address),
                p_address (p_address)
            Return: currentStatus (current state of the drug in the supply chain)
            Operation: verify the drug by cross-checking all the addresses and the drug status
        */
        
        /*
            Reference:
                statusCode 0: "Drug is ILLEGAL, one or more of Manufacturer / Distributor / Pharmacist addresses is not registered by the FDA"
                statusCode 1: "Drug is LEGAL and VERIFIED, addresses verified and item dispensed properly"
                statusCode 2: "Drug is not yet dispensed to the consumer, might be experimental (or) might have entered the supply chain ILLEGALLY"
        */
        
        
        // Check if valid address
        if(roles[m_address] != role.Manufacturer || roles[d_address] != role.Distributor || roles[p_address] != role.Pharmacist){
            return (0);
        }
        
        // Check if valid drug status
        if(directory[_ndc].state == State.Dispensed && directory[_ndc].owner == p_address){
            return (1);
        }
        else{
            return (2);
        }
        
    }
    
    function getStatus(uint _ndc) public view returns(State state, address owner, uint256 price) { 
        
        /*
            Input: _ndc (10 digit National Drug Code [NDC] generated by the Manufacturer)
            Return: currentStatus (current state of the drug in the supply chain)
            Operation: Get the current state, owner and the sale price of the drug
        */
        
        return (directory[_ndc].state, directory[_ndc].owner, directory[_ndc].price);
        
    }
    
            /******************* Public method for secure updation of hash *************************/
            
    function updateHash(bytes32 _nexthash) public {
        filehash = _nexthash;           // Update current hash to new hash
    }
    
}