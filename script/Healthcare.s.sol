// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {Healthcare} from "../src/Healthcare.sol";

contract HealthcareScript is Script {
    Healthcare public _Healthcare;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        _Healthcare = new Healthcare();

        vm.stopBroadcast();
    }
}
