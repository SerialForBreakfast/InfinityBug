# Project Directory Structure

```
InfinityBug/
├── .git/
├── .cursor/
├── InfinityBug/
│   ├── ViewController.swift
│   └── AppDelegate.swift
├── InfinityBugTests/
│   └── InfinityBugTests.swift
├── InfinityBugUITestsNew/
│   └── InfinityBugUITestsNew.swift
├── InfinityBug.xcodeproj/
├── utilities/
│   ├── build_and_test_all.sh
│   └── build_all.sh
├── memlog/
│   ├── changelog.md
│   ├── directory_tree.md
│   ├── tasks.md
│   ├── architecture_fix_summary.md
│   ├── architecture_correction.md
│   ├── fix_completion_summary.md
│   ├── implementation_summary.md
│   └── channel_population_analysis.md
└── build_results/
    └── build_YYYYMMDD_HHMMSS/
        ├── build_summary.txt
        └── logs/
            ├── InfinityBug_build.log
            ├── InfinityBugTests_build.log
            ├── InfinityBugTests_test.log
            ├── InfinityBugUITestsNew_build.log
            └── InfinityBugUITestsNew_test.log
```

## Key Directories

### Source Code
- `InfinityBug/`: Main application source code
- `InfinityBugTests/`: Unit tests
- `InfinityBugUITestsNew/`: UI tests

### Build and Utilities
- `utilities/`: Build and test scripts
- `build_results/`: Build artifacts and logs

### Documentation
- `memlog/`: Project documentation and tracking
  - `changelog.md`: Version history and changes
  - `directory_tree.md`: Project structure
  - `tasks.md`: Current and planned tasks
  - Other analysis and summary documents

## File Descriptions

### Build Scripts
- `build_and_test_all.sh`: Comprehensive build and test execution
- `build_all.sh`: Build-only execution

### Documentation
- `changelog.md`: Tracks all changes to the project
- `directory_tree.md`: Documents project structure
- `tasks.md`: Tracks current and planned tasks
- Various analysis documents for architecture and implementation details 