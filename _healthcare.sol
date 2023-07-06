pragma solidity ^0.8.18;
import "@openzeppelin/contracts/utils/Strings.sol";

contract Healthcare{
    string title;
    address Admin;
    mapping (address => Patient) patients;
    mapping (address => Doctor) doctors;
    mapping (address => Session) sessions;

    mapping(uint => Patient) patients_to_show;
    mapping(uint => address) patients_addresses;
    uint patients_cnt;

    mapping(uint => Doctor) doctors_to_show;
    mapping(uint => address) doctors_addresses;
    uint doctors_cnt;

    mapping(uint => Session) sessions_to_show;
    mapping(uint => address) sessions_addresses;
    uint sessions_cnt;

    //mapping (address => bool) PatientAwaitingDoctor;
    //mapping (address => bool) DoctorAvailable;

    uint amount = 100000000000000000 wei;

    struct Patient{
        bool IsMember;
        bool RegistrationPending;
        bool Rejected;
        string UserName;
        bool WaitingForDoctor;
    }

    struct Doctor{
        bool IsMember;
        bool RegistrationPending;
        bool Rejected;
        string UserName;
        string Certificate;
        bool Available;
    }

    struct Session{
        address patient;
        address doctor;
        string description;
        bool PaymentDone;
        string IPFShash;
    }

    constructor(string memory _title){
        Admin = msg.sender;
        title = _title;
    }

    function setAmount(uint w) public {
        require(
            msg.sender == Admin,
            "Only admin can perform this operation."
        );

        amount = w;
    }

    //patient sends registration request
    function RegisterPatientRequest(/*address p_addr, */string memory Username) public{
        require(
            !patients[msg.sender].RegistrationPending,
            "You already submitted registration request..."
        ); 
        require(
            !patients[msg.sender].Rejected,
            "You are not valid to register"
        );
        require(
            !patients[msg.sender].IsMember,
            "You are already registered..."
        );
        require(
            bytes(Username).length!=0,
            "Please enter your username"
        );

        patients[msg.sender].RegistrationPending = true;
        patients[msg.sender].UserName = Username;
        patients_to_show[patients_cnt] = patients[msg.sender];//added
        patients_addresses[patients_cnt] = msg.sender;
        patients_cnt++;//added
        //ps.push(patients[msg.sender]);
    }

    //Admin Accepts/rejects registration request
    function ValidatePatientRegistration(address p_addr, bool Accepted) public{
        require(
            msg.sender == Admin,
            "Only Admin can perform this operation"
        ); 
        require(
            patients[p_addr].RegistrationPending,
            "This address did not request for registration as patient."
        ); 

        patients[p_addr].RegistrationPending = false;
        patients[p_addr].IsMember = Accepted;
        patients[p_addr].Rejected = !Accepted;
        //patients[msg.sender].M_REC = [];
    }

    function RegisterDoctorRequest(string memory Username, string memory Cert) public{
        require(
            !doctors[msg.sender].RegistrationPending,
            "You already submitted registration request..."
        ); 
        require(
            !doctors[msg.sender].Rejected,
            "You are not valid to register"
        );
        require(
            !doctors[msg.sender].IsMember,
            "You are already registered."
        );
        require(
            bytes(Username).length!=0,
            "Please enter your username"
        );
        doctors[msg.sender].RegistrationPending = true;
        doctors[msg.sender].UserName = Username;
        doctors[msg.sender].Certificate = Cert;
        doctors_to_show[doctors_cnt] = doctors[msg.sender];//added
        doctors_addresses[doctors_cnt] = msg.sender;
        doctors_cnt++;//added
        //ds.push(doctors[msg.sender]);
    }

    //Admin accepts/rejects registration request
    function ValidateDoctorRegistration(address d_addr, bool Accepted) public{
        require(
            msg.sender == Admin,
            "Only Admin can perform this operation"
        ); 
        require(
            doctors[d_addr].RegistrationPending,
            "This address did not request for registration as doctor."
        ); 

        doctors[d_addr].RegistrationPending = false;
        doctors[d_addr].IsMember = Accepted;
        doctors[d_addr].Rejected = !Accepted;
        doctors[d_addr].Available = true;
        //DoctorAvailable[msg.sender] = true;
    }

    ///////////////////////////////////////////////////////////////////////
    //event Receive(uint value);
    function RequestDoctor(string memory description, string memory MessageHash) public payable returns(address){
        require(
            patients[msg.sender].IsMember,
            "You are not registered as patient in this smart contract!"
        ); 
        require(
            !patients[msg.sender].WaitingForDoctor,
            "You already submitted a request for doctor!"
        ); 
        require(
            msg.value >= amount,
            string.concat(string.concat("You need to pay at least ", Strings.toString(amount)), " wei.")
        );

        //emit Receive(msg.value);

        patients[msg.sender].WaitingForDoctor = true;

        Session memory s = Session({
            patient : msg.sender, 
            doctor: address(0), 
            IPFShash: MessageHash, 
            PaymentDone : false,
            description : description
            });

        address rand_addr = address(bytes20(keccak256(abi.encodePacked(block.timestamp))));
        sessions[rand_addr] = s;

        sessions_to_show[sessions_cnt] = sessions[rand_addr]; //sessions[msg.sender];
        sessions_addresses[sessions_cnt] = rand_addr;
        sessions_cnt++;//added

        return rand_addr; 
    }

    function AssignDoctor(address sess, address pat, address doc) public{
        require(
            msg.sender==Admin,
            "You do not have permission to perform operation."
        ); 
        require(
            //patients[sessions[sess].patient].IsMember,
            patients[pat].IsMember,
            "Patient address does not exist."
        ); 
        require(
            sessions[sess].patient == pat,
            "This patient does not belong to this session."
        ); 
        require(
            doctors[doc].IsMember,
            "Doctor address does not exist."
        );
        require(
            doctors[doc].Available,
            "Doctor is not available."
        );

        doctors[doc].Available = false;

        patients[pat].WaitingForDoctor = false;
    }

    //let doctor/patient access record data (including upfs hash)
    function Get_session_data(address sess) public view returns (Session memory){
        require(
                sessions[sess].doctor == msg.sender || sessions[sess].patient == msg.sender || msg.sender == Admin,
                "You don't have permission to access session's data."
            );

            return sessions[sess];
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////
    //Escrow Service:
    //function Pay2Doc
    function Pay2Doc(address sess) public payable {
        require(
            Admin == msg.sender || sessions[sess].patient == msg.sender ,
            "You don't have permission to access session's data."
        );
        require(
            !sessions[sess].PaymentDone ,
            "The payment is already done."
        );

        //bool sent = payable(sessions[sess].doctor).send(amount);
        //require(sent, "Transaction failed");

        sessions[sess].PaymentDone = true;
        patients[sessions[sess].patient].WaitingForDoctor = false;
        doctors[sessions[sess].doctor].Available = true;
        
    }


    //function PayBack2Patient
    function PayBack2Patient(address sess) public payable{
        require(
            sessions[sess].doctor == msg.sender || Admin == msg.sender ,
            "You don't have permission to perform this operation."
        );
        require(
            sessions[sess].doctor == msg.sender || Admin == msg.sender ,
            "You don't have permission to access session's data."
        );

        //bool sent = payable(sessions[sess].patient).send(amount);
        //require(sent, "Transaction failed");

        sessions[sess].PaymentDone = true;
        patients[sessions[sess].patient].WaitingForDoctor = false;
        doctors[sessions[sess].doctor].Available = true;
    }


    //half-payback if patient is fake
    //prevents request spamming
    function HalfPayBack(address sess) public payable{
        require(
            sessions[sess].doctor == msg.sender || Admin == msg.sender ,
            "You don't have permission to perform this operation."
        );
        require(
            !sessions[sess].PaymentDone ,
            "The payment is already done."
        );

        //bool sent1 = payable(sessions[sess].patient).send(amount/2);
        //require(sent1,"failed to pay patient.");

        //bool sent2 = payable(sessions[sess].doctor).send(amount/2);
        //require(sent2,"failed to pay doctor.");

        sessions[sess].PaymentDone = true;
        patients[sessions[sess].patient].WaitingForDoctor = false;
        doctors[sessions[sess].doctor].Available = true;
    }

    ///////////////////////////////////////////////////////////////////
    //GETTERS
    function get_patients() public view returns (Patient[] memory, address[] memory){
        require(
            msg.sender==Admin,
            "You do not have permission to view patients list."
        );

        Patient[] memory ret = new Patient[](patients_cnt);
        address[] memory retAddr = new address[](patients_cnt);
        for (uint i = 0; i < patients_cnt; i++) {
            ret[i] = patients_to_show[i];
            retAddr[i] = patients_addresses[i];
        }
        return (ret, retAddr);
    }

    function get_doctors() public view returns (Doctor[] memory, address[] memory){
        require(
            msg.sender==Admin,
            "You do not have permission to view doctors list."
        );

        Doctor[] memory ret2 = new Doctor[](doctors_cnt);
        address[] memory retAddr2 = new address[](doctors_cnt);
        for (uint i = 0; i < doctors_cnt; i++) {
            ret2[i] = doctors_to_show[i];
            retAddr2[i] = doctors_addresses[i];
        }
        return (ret2, retAddr2);
    }

    function get_sessions() public view returns (Session[] memory, address[] memory){
        require(
            msg.sender==Admin,
            "You do not have permission to view sessions list."
        );

        Session[] memory ret = new Session[](sessions_cnt);
        address[] memory retAddr = new address[](sessions_cnt);
        for (uint i = 0; i < sessions_cnt; i++) {
            ret[i] = sessions_to_show[i];
            retAddr[i] = sessions_addresses[i];
        }
        return (ret, retAddr);
    }
}
