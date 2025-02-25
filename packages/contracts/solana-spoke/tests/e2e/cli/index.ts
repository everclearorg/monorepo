#!/usr/bin/env node

import { Command } from 'commander';
import * as fs from 'fs-extra';
import * as path from 'path';
import { config } from 'dotenv';
import chalk from 'chalk';
import { createEnvFileIfNotExists } from '../config/environment';

// Ensure the .env file exists
createEnvFileIfNotExists();

// Load environment variables from .env file
config();

const program = new Command();

program
  .name('spoke-cli')
  .description('CLI tool for testing Everclear Solana Spoke contracts')
  .version('1.0.0');

// Dynamically load all command modules from the commands directory
const commandsDir = path.join(__dirname, 'commands');
if (fs.existsSync(commandsDir)) {
  fs.readdirSync(commandsDir)
    .filter(file => file.endsWith('.js'))
    .forEach(file => {
      const commandModule = require(path.join(commandsDir, file));
      if (commandModule.default) {
        program.addCommand(commandModule.default);
      }
    });
}

program.parse(process.argv);

// If no command is provided, show help
if (!process.argv.slice(2).length) {
  program.outputHelp();
} 