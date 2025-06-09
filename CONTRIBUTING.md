# Contributing to Velib Balancer Optimization

We welcome contributions of all kinds: bug reports, feature requests, documentation improvements, tests, and new algorithms.

## Getting Started

1. Fork the repository  
2. Clone your fork  
   ```bash
   git clone https://github.com/yourusername/velib-balancer-optimisation.git
   cd velib-balancer-optimisation
   ```  
3. Verify Julia installation
   ```bash
   julia --version
   ```

## How to Contribute

### Reporting Issues
- Open an issue with a descriptive title and steps to reproduce.
- Tag it as `bug` or `enhancement`.

### Pull Requests
1. Create a branch:  
   ```bash
   git checkout -b feature/my-feature
   ```
2. Make changes, following the Julia style guidelines below.
3. Test locally:
   ```bash
   julia src/recuit_simule_solution.jl 
   julia src/zones_progressives_solution.jl 
   ```
4. Commit with a clear message, push, and open a PR.

### Coding Guidelines
- Use 4 spaces for indentation.  
- `snake_case` for functions/variables; `PascalCase` for types.  
- Document public functions with docstrings.  
- Keep lines ≤ 92 characters.

## 🧩 Additional Guidelines

- Focus contributions on the two main algorithms currently implemented in [`src/recuit_simule_solution.jl`](src/recuit_simule_solution.jl) and [`src/zones_progressives_solution.jl`](src/zones_progressives_solution.jl).
- Ensure any new algorithms or utilities are well documented and tested.
- Maintain consistency with existing code style and project structure.
- Update README.md and documentation when adding new features or algorithms.
- When adding visualizations, place them in the [`plots/`](plots/) directory.
- Mathematical documentation should be added to [`docs/modelisation/`](docs/modelisation/).

## 📊 Project Structure Notes

This project uses a simple Julia structure without formal package management:
- No `Project.toml` or `Manifest.toml` files
- Dependencies are imported directly in source files
- Algorithms output to console rather than files
- Performance plots are pre-generated in [`plots/`](plots/) directory
