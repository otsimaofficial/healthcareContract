// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Healthcare
 * @dev A smart contract for a blockchain-based healthcare management system.
 * This contract handles patient registration, appointment scheduling,
 * medical record management, and access control for different user roles.
 */
contract Healthcare {
    // --- State Variables ---

    // Enum to represent different user roles
    enum Role {
        Patient,
        Doctor,
        Lab,
        Admin,
        None
    }

    // Structs to define data structures
    struct Patient {
        address patientAddress;
        string name;
        uint256 age;
        string contactInfo;
        bool isRegistered;
    }

    struct Appointment {
        address patientAddress;
        address doctorAddress;
        uint256 appointmentTime; // Timestamp
        bool isConfirmed;
    }

    struct MedicalRecord {
        address patientAddress;
        address doctorAddress;
        string diagnosis;
        string prescription;
        string labResultsIPFSHash; // IPFS hash to a larger file
        uint256 timestamp;
    }

    // Mappings to store user information and records
    mapping(address => Role) public userRoles;
    mapping(address => Patient) public patients;
    mapping(address => bool) public registeredDoctors;
    mapping(address => bool) public registeredLabs;
    mapping(uint256 => Appointment) public appointments;
    mapping(uint256 => MedicalRecord) public medicalRecords;
    mapping(address => uint256[]) public patientAppointments;
    mapping(address => uint256[]) public patientRecords;
    mapping(address => uint256[]) public doctorRecords;

    // Counters for unique IDs
    uint256 private nextAppointmentId = 0;
    uint256 private nextRecordId = 0;

    // --- Events ---

    event PatientRegistered(address indexed patientAddress, string name);
    event DoctorRegistered(address indexed doctorAddress);
    event LabRegistered(address indexed labAddress);
    event AppointmentScheduled(
        address indexed patientAddress,
        address indexed doctorAddress,
        uint256 appointmentId
    );
    event AppointmentConfirmed(
        uint256 indexed appointmentId,
        address indexed doctorAddress
    );
    event MedicalRecordAdded(
        address indexed patientAddress,
        address indexed doctorAddress,
        uint256 recordId
    );
    event AccessGranted(address indexed recordOwner, address indexed accessor);

    // --- Modifiers ---

    modifier onlyRole(Role requiredRole) {
        require(
            userRoles[msg.sender] == requiredRole,
            "Access denied: incorrect role."
        );
        _;
    }

    modifier onlyPatient(address patientAddress) {
        require(
            userRoles[msg.sender] == Role.Patient &&
                msg.sender == patientAddress,
            "Access denied: not the patient."
        );
        _;
    }

    modifier onlyDoctor(address doctorAddress) {
        require(
            userRoles[msg.sender] == Role.Doctor && msg.sender == doctorAddress,
            "Access denied: not the doctor."
        );
        _;
    }

    modifier onlyDoctorOrPatient(address recordOwner) {
        require(
            userRoles[msg.sender] == Role.Doctor ||
                (userRoles[msg.sender] == Role.Patient &&
                    msg.sender == recordOwner),
            "Access denied: not doctor or patient."
        );
        _;
    }

    // --- Constructor ---

    constructor() {
        // The address that deploys the contract is the Admin
        userRoles[msg.sender] = Role.Admin;
    }

    // --- User Management Functions (Admin Only) ---

    /**
     * @dev Admin function to register a doctor.
     * @param _doctorAddress The address of the doctor to register.
     */
    function registerDoctor(
        address _doctorAddress
    ) public onlyRole(Role.Admin) {
        require(
            !registeredDoctors[_doctorAddress],
            "Doctor already registered."
        );
        userRoles[_doctorAddress] = Role.Doctor;
        registeredDoctors[_doctorAddress] = true;
        emit DoctorRegistered(_doctorAddress);
    }

    /**
     * @dev Admin function to register a lab.
     * @param _labAddress The address of the lab to register.
     */
    function registerLab(address _labAddress) public onlyRole(Role.Admin) {
        require(!registeredLabs[_labAddress], "Lab already registered.");
        userRoles[_labAddress] = Role.Lab;
        registeredLabs[_labAddress] = true;
        emit LabRegistered(_labAddress);
    }

    // --- Patient Functions ---

    /**
     * @dev Allows a patient to register themselves.
     * @param _name The patient's name.
     * @param _age The patient's age.
     * @param _contactInfo The patient's contact information.
     */
    function registerPatient(
        string memory _name,
        uint256 _age,
        string memory _contactInfo
    ) public {
        require(
            userRoles[msg.sender] == Role.None,
            "Address already has a role."
        );
        patients[msg.sender] = Patient(
            msg.sender,
            _name,
            _age,
            _contactInfo,
            true
        );
        userRoles[msg.sender] = Role.Patient;
        emit PatientRegistered(msg.sender, _name);
    }

    /**
     * @dev Allows a patient to schedule an appointment with a doctor.
     * @param _doctorAddress The address of the doctor for the appointment.
     * @param _appointmentTime The timestamp for the appointment.
     */
    function scheduleAppointment(
        address _doctorAddress,
        uint256 _appointmentTime
    ) public onlyRole(Role.Patient) {
        require(registeredDoctors[_doctorAddress], "Doctor is not registered.");

        uint256 appointmentId = nextAppointmentId++;
        appointments[appointmentId] = Appointment(
            msg.sender,
            _doctorAddress,
            _appointmentTime,
            false
        );
        patientAppointments[msg.sender].push(appointmentId);

        emit AppointmentScheduled(msg.sender, _doctorAddress, appointmentId);
    }

    // --- Doctor Functions ---

    /**
     * @dev Allows a doctor to confirm an appointment.
     * @param _appointmentId The ID of the appointment to confirm.
     */
    function confirmAppointment(
        uint256 _appointmentId
    ) public onlyRole(Role.Doctor) {
        Appointment storage appointment = appointments[_appointmentId];
        require(
            appointment.doctorAddress == msg.sender,
            "You are not the assigned doctor for this appointment."
        );
        require(!appointment.isConfirmed, "Appointment already confirmed.");

        appointment.isConfirmed = true;
        emit AppointmentConfirmed(_appointmentId, msg.sender);
    }

    /**
     * @dev Allows a doctor to add a medical record for a patient.
     * @param _patientAddress The address of the patient.
     * @param _diagnosis The diagnosis string.
     * @param _prescription The prescription string.
     * @param _labResultsIPFSHash The IPFS hash for lab results.
     */
    function addMedicalRecord(
        address _patientAddress,
        string memory _diagnosis,
        string memory _prescription,
        string memory _labResultsIPFSHash
    ) public onlyRole(Role.Doctor) {
        require(
            patients[_patientAddress].isRegistered,
            "Patient is not registered."
        );

        uint256 recordId = nextRecordId++;
        medicalRecords[recordId] = MedicalRecord(
            _patientAddress,
            msg.sender,
            _diagnosis,
            _prescription,
            _labResultsIPFSHash,
            block.timestamp
        );
        patientRecords[_patientAddress].push(recordId);
        doctorRecords[msg.sender].push(recordId);

        emit MedicalRecordAdded(_patientAddress, msg.sender, recordId);
    }

    // --- Lab Functions ---

    /**
     * @dev Allows a lab to add lab results to a patient's record.
     * @param _recordId The ID of the medical record to update.
     * @param _labResultsIPFSHash The IPFS hash for the lab results.
     */
    function addLabResults(
        uint256 _recordId,
        string memory _labResultsIPFSHash
    ) public onlyRole(Role.Lab) {
        require(
            medicalRecords[_recordId].patientAddress != address(0),
            "Record does not exist."
        );

        medicalRecords[_recordId].labResultsIPFSHash = _labResultsIPFSHash;

        // This is a simplified approach. In a real system, the lab would likely
        // be tied to a specific appointment or a doctor's request.
    }
}
