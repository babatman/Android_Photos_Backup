# Advanced Android MTP Backup Module for PowerShell

![PowerShell Version](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)
![Platform Support](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey)

A professional-grade PowerShell module for backing up Android devices via MTP protocol, optimized for 2025 flagship devices like the **Samsung Galaxy S25 Ultra** (7th best-selling smartphone globally in Q1 2025[5][10]).

## Features
- 🔄 Recursive backup of nested directories
- 📊 Real-time progress tracking and statistics
- 🔒 Error handling with automatic retries (3 attempts default)
- 📱 Verified compatibility with Galaxy S25 Ultra MTP implementation
- 📅 Last tested with Windows 11 24H2 MTP stack


## Clone repository

git clone https://github.com/yourusername/Android-MTP-Backup.git
Set-ExecutionPolicy RemoteSigned -Scope Process
Import-Module .\Android-MTP-Backup.psm1