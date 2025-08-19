# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is an Obsidian vault containing a comprehensive daily notes template system. The repository consists of a single, feature-rich Markdown template file that uses Templater plugin functionality for productivity tracking and task management.

## Key Files

- `daily-notes.md`: A comprehensive daily notes template with advanced Templater functionality for dynamic content generation, automatic file organization, and integrated task management
- `devops-daily-log.md`: A focused daily work log template specifically designed for DevOps/SRE/SWE professionals to track technical work, incidents, and system operations

## Template Architecture

The daily notes template implements several sophisticated patterns:

### Automated File Management
- Uses Templater's `tp.file.move()` to automatically organize notes into `Journal/Daily/` folder structure
- Implements robust folder creation logic with error handling
- Names files using YYYY-MM-DD format for consistent chronological organization
- Includes try-catch error handling for file operations

### Enhanced Metadata Structure
- Dynamic frontmatter with date, weekday, and week number
- Hierarchical tagging system (yearly, monthly)
- Structured aliases for easy reference

### Plugin Dependencies & Validation
- **Required plugins**: Dataview, Tasks, and Templater
- Comprehensive runtime validation with user-friendly error messages
- Graceful degradation when plugins are missing

### Complete Daily Workflow System
The template provides a comprehensive productivity framework:

#### Task Management
- Multiple task query views (overdue, due today, due this week)
- Integrated Tasks plugin queries with sorting and limits
- In-progress task tracking section

#### Planning & Reflection
- Morning planning section with energy level and focus tracking
- Evening reflection with accomplishments, challenges, and lessons learned
- Tomorrow's preparation checklist
- Gratitude practice integration

#### Professional/DevOps Features
- Systems & operations health check section
- Metrics and KPIs tracking
- Meeting and call scheduling table
- Ideas and notes capture

#### Navigation & Integration
- Quick links to weekly and monthly reviews
- Previous/next day navigation
- Dynamic linking to review templates

#### Advanced Dataview Integration
- Recently modified files tracking
- Task creation analytics
- Automated daily metrics collection

## Usage Best Practices

### Template Deployment
1. Place template in Obsidian Templates folder
2. Ensure required plugins (Templater, Tasks, Dataview) are installed and enabled
3. Configure Templater to use this template for daily note creation

### Folder Structure
The templates expect and create:
```
Journal/
├── Daily/
│   ├── YYYY-MM-DD.md (daily notes)
├── Weekly/
│   ├── Weekly Review - YYYY-WWW.md (optional)
└── Monthly/
    └── Monthly Review - YYYY-MM.md (optional)

Logs/
└── Daily/
    └── YYYY-MM-DD.md (work logs)
```

### Integration Points
- Links to weekly and monthly review templates (create separately)
- Supports task management workflow with due dates and priorities
- Integrates with Obsidian's daily notes plugin for seamless note creation

## Templates Overview

### daily-notes.md - Comprehensive Personal Productivity
A sophisticated personal productivity template with task management, planning, and reflection sections. Includes advanced Dataview queries and integration with Tasks plugin.

### devops-daily-log.md - Professional Work Log
A focused technical work log template designed specifically for DevOps/SRE/SWE professionals, featuring:

- **Work Tracking**: Organized sections for infrastructure, development, deployments, and bug fixes
- **Incident Management**: Structured tables for tracking active and resolved incidents
- **System Monitoring**: Health metrics, alerts, and performance monitoring sections
- **Technical Tasks**: Completed, in-progress, and blocked task tracking
- **Learning & Research**: Documentation of new technologies and knowledge gaps
- **Team Collaboration**: Meeting notes, code reviews, and team communication
- **Priority Planning**: Tomorrow's priorities and follow-up items
- **Technical Notes**: Insights, process improvements, and observations

Both templates auto-organize files into appropriate folder structures and provide consistent navigation between days.

## Development Context

This repository provides two complementary Obsidian templates: a comprehensive personal productivity system and a focused professional work log, both optimized for technical professionals. The templates leverage Obsidian's powerful linking capabilities and Templater automation for seamless daily documentation workflows.