# Creating extractoR Roadmap Issues on GitHub

This directory contains scripts to create 37 comprehensive roadmap issues for the extractoR package.

## Quick Start

### Option 1: Automated Creation (Recommended)

1. **Create a GitHub Personal Access Token:**
   - Go to: https://github.com/settings/tokens/new
   - Give it a name like "extractoR issue creation"
   - Select scope: `repo` (Full control of private repositories)
   - Click "Generate token"
   - Copy the token (you won't see it again!)

2. **Set the token in your environment:**
   ```bash
   export GITHUB_TOKEN='your_token_here'
   ```

3. **Run the creation script:**
   ```bash
   chmod +x run_create_issues.sh
   ./run_create_issues.sh
   ```

   Or directly:
   ```bash
   python3 create_issues.py
   ```

### Option 2: Manual Creation

If you prefer to create issues manually or want to review them first:

1. **Review the roadmap:**
   Open `.github/ROADMAP_ISSUES.md` to see all 37 issues with full details

2. **Create issues one by one:**
   - Go to: https://github.com/SkanderMulder/extractoR/issues/new
   - Copy title and body from the roadmap document
   - Add the appropriate labels
   - Submit

### Option 3: Using GitHub CLI

If you have `gh` CLI installed:

```bash
# This would require creating a shell script to parse the roadmap
# and create issues using gh commands
```

## What Issues Will Be Created?

The script creates **37 comprehensive issues** organized into:

### Phase 1: CRAN Preparation (5 issues)
- Run full CRAN checks
- Set up GitHub Actions CI
- Achieve 90%+ test coverage
- Create pkgdown website
- Submit to CRAN

### Phase 2: Usability & Developer Experience (6 issues)
- Auto-schema inference
- One-liner extraction
- Progress indicators
- Batch processing with parallelization
- Enhanced error messages
- Schema templates

### Phase 3: Ecosystem Integration (7 issues)
- Auto-detect model types
- Tidymodels/recipes integration
- Targets/drake integration
- Shiny module
- Plumber API integration
- R Markdown/Quarto support
- ellmer collaboration

### Phase 4: Production Readiness (6 issues)
- Streaming extraction
- Persistent caching
- Rate limiting & cost tracking
- Validation-only mode
- Audit logging
- Pro mode with SQLite

### Phase 5: Community & Dominance (6 issues)
- Comprehensive vignettes
- Project templates
- Talks & blog posts
- Benchmarks vs Python
- Posit partnership
- Contribution guidelines

### Bonus Features (5 issues)
- Zero-shot schema learning
- Human-in-the-loop fallback
- Arrow/DuckDB export
- Evaluation framework
- Model comparison utilities

### Meta (1 issue)
- Analytics dashboard

### Quick Wins (1 issue)
- Community outreach

## Priority Distribution

- **Critical Priority:** 1 issue
- **High Priority:** 15 issues
- **Medium Priority:** 17 issues
- **Low Priority:** 7 issues

## Timeline

- **Phase 1 (Weeks 1-3):** CRAN preparation
- **Phase 2 (Weeks 4-6):** Usability improvements
- **Phase 3 (Weeks 7-10):** Ecosystem integration
- **Phase 4 (Weeks 11-14):** Production readiness
- **Phase 5 (Ongoing):** Community building

## After Creating Issues

1. **Review and adjust:**
   - Adjust priorities based on current needs
   - Add milestones
   - Assign issues to team members

2. **Create a project board:**
   - Group issues by phase
   - Track progress visually

3. **Start with quick wins:**
   - Deploy pkgdown site (#4)
   - Add progress examples (#8)
   - Create invoice template (#11)
   - Post to r/rstats (#40)

## Troubleshooting

### "Authentication failed"
- Make sure your GitHub token has the `repo` scope
- Check that the token hasn't expired
- Verify you're using the correct token

### "Rate limit exceeded"
- GitHub has API rate limits
- The script waits 1 second between requests to be respectful
- If you hit limits, wait an hour and retry

### Script fails partway through
- The script will show which issues were created and which failed
- You can manually create the remaining issues
- Or modify the `issues` list in `create_issues.py` to skip already-created ones

## Files

- **`.github/ROADMAP_ISSUES.md`** - Full roadmap with all issue details
- **`create_issues.py`** - Python script to create issues via GitHub API
- **`run_create_issues.sh`** - Shell wrapper that checks for token
- **`CREATE_ISSUES_README.md`** - This file

## Need Help?

- Check the roadmap document for full issue details
- Review the Python script to understand what it does
- Open an issue on GitHub if you encounter problems
