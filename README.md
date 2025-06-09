# Velib Balancer Optimization

A comprehensive optimization project for solving the Velib (bike-sharing) station balancing problem using multiple algorithmic approaches including simulated annealing and progressive zone balancing.

## 🚴‍♂️ Problem Description

The Velib balancing problem involves optimizing the redistribution of bikes across stations in a bike-sharing network. The goal is to minimize the total distance traveled by a truck while ensuring each station reaches its ideal number of bikes, subject to truck capacity constraints.

### Key Elements:
- **Stations**: Each with current bikes, capacity, and ideal target
- **Truck**: Limited capacity for transporting bikes
- **Objective**: Minimize total travel distance while balancing stations
- **Constraints**: Truck capacity, station capacities, and routing constraints

## 📁 Project Structure

```
velib-balancer-optimisation/
├── src/                          # Source code
│   ├── recuit_simule_solution.jl     # Simulated annealing implementation
│   └── zones_progressives_solution.jl # Progressive zone balancing
├── docs/                         # Documentation
│   ├── Projet_Velib.pdf             # Project specification (French)
│   ├── modelisation/
│   │   └── Modelisation_Velib.md    # Mathematical modeling (French)
│   └── report/                      # Project report
│       ├── report.pdf               # Compiled report
│       └── report.tex               # LaTeX source
├── instances/                    # Test instances
│   ├── tsdp_1_s10_k6.dat           # Small instance (10 stations)
│   ├── tsdp_2_s20_k11.dat          # Medium instances (20 stations)
│   ├── tsdp_4_s50_k10.dat          # Large instances (50+ stations)
│   └── ...                         # Up to 500 stations (9 total)
├── plots/                        # Generated visualization plots
│   ├── desequilibre.png             # Imbalance analysis
│   ├── distance.png                 # Distance optimization results
│   └── temps.png                    # Execution time analysis
├── LICENSE                       # MIT License
├── .gitignore                    # Git ignore rules
├── CONTRIBUTING.md               # Contribution guidelines
└── README.md                     # This file
```

## 🛠️ Requirements

### System Requirements
- **Julia**: Version 1.6+ (recommended: 1.9+)
- **Operating System**: Linux, macOS, or Windows
- **Memory**: Minimum 4GB RAM (8GB+ recommended for large instances)

### Julia Dependencies
The project uses standard Julia libraries:
```julia
using Random, Printf
```

## 🚀 Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/velib-balancer-optimisation.git
   cd velib-balancer-optimisation
   ```

2. **Verify Julia installation:**
   ```bash
   julia --version
   ```

3. **Test the algorithms:**
   ```bash
   julia src/recuit_simule_solution.jl 
   ```

> **Note**: This project doesn't use a formal Julia package structure (no `Project.toml`). Dependencies are imported directly in the source files.

## 📊 Usage

### Running Algorithms

#### Simulated Annealing
```bash
julia src/recuit_simule_solution.jl 
```

#### Progressive Zone Balancing
```bash
julia src/zones_progressives_solution.jl
```

### Instance Format

Instance files (`.dat`) contain:
```
name instance_name
K truck_capacity
stations
# id  x  y  nbp  cap  ideal
1    19 74   5   10     9
2    41 10   7   12     7
...
warehouse x y
```

Where:
- `id`: Station identifier
- `x, y`: Station coordinates
- `nbp`: Current number of bikes
- `cap`: Station capacity
- `ideal`: Target number of bikes

## 🧮 Algorithms Implemented

### 1. Simulated Annealing (`src/recuit_simule_solution.jl`)
- **Approach**: Metaheuristic optimization with temperature cooling
- **Features**: Lexicographic optimization, neighborhood exploration
- **Best for**: Medium to large instances with quality solutions

### 2. Progressive Zone Balancing (`src/zones_progressives_solution.jl`)
- **Approach**: Divide stations into zones and balance progressively
- **Features**: Hierarchical optimization, zone-based routing
- **Best for**: Large instances with geographical clustering

## 📈 Performance Benchmarks

| Instance | Stations | Algorithm | Distance | Time (s) |
|----------|----------|-----------|----------|----------|
| tsdp_1   | 10       | SA        | 150     | <1       |
| tsdp_4   | 50       | SA        | 800     | 5-10     |
| tsdp_9   | 500      | Zones     | 2500    | 30-60    |

*Results may vary based on hardware and parameter settings*

## 🔧 Configuration

## 📝 Output Format

Algorithm outputs are displayed to the console and include:
- **Solution route**: Order of station visits
- **Bike transfers**: Number of bikes loaded/unloaded at each station
- **Total distance**: Objective function value
- **Execution time**: Algorithm runtime
- **Solution quality**: Feasibility and optimality metrics

## 📊 Visualization

The project includes performance analysis plots in the [`plots/`](plots/) directory:
- [`plots/distance.png`](plots/distance.png): Distance optimization results
- [`plots/desequilibre.png`](plots/desequilibre.png): Station imbalance analysis
- [`plots/temps.png`](plots/temps.png): Algorithm execution time comparison

## 🧪 Testing

### Run Test Suite
```bash
# Test on small instance
julia src/recuit_simule_solution.jl instances/tsdp_1_s10_k6.dat

# Test progressive zones algorithm
julia src/zones_progressives_solution.jl instances/tsdp_1_s10_k6.dat

# Compare algorithms on all instances
for file in instances/*.dat; do
    echo "Testing $file"
    julia src/recuit_simule_solution.jl "$file"
done
```

## 🧩 Implementation Notes

- The project implements two main optimization algorithms:
  1. **Lexicographic Simulated Annealing** ([`src/recuit_simule_solution.jl`](src/recuit_simule_solution.jl))
  2. **Progressive Zone Balancing** ([`src/zones_progressives_solution.jl`](src/zones_progressives_solution.jl))

- All algorithms are implemented in pure Julia without external optimization packages
- Performance analysis and visualizations are available in the [`plots/`](plots/) directory
- Detailed mathematical modeling is documented in French in [`docs/modelisation/Modelisation_Velib.md`](docs/modelisation/Modelisation_Velib.md)


### Validate Solutions
Monitor console output for solution quality and feasibility metrics.

## 🤝 Contributing

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### Development Guidelines
- Follow Julia style conventions
- Add tests for new algorithms
- Update documentation for new features
- Ensure backward compatibility


## 📚 Documentation

- **Mathematical Model**: [`docs/modelisation/Modelisation_Velib.md`](docs/modelisation/Modelisation_Velib.md)
- **Project Specification**: [`docs/Projet_Velib.pdf`](docs/Projet_Velib.pdf)
- **Project Report**: [`docs/report/report.pdf`](docs/report/report.pdf)
- **Algorithm Details**: See individual source file headers

## 📄 License

This project is licensed under the MIT License - see the [`LICENSE`](LICENSE) file for details.

## 👥 Authors

- **Author**: Nazim KESKES
- **Institution**: Master 2 ISD
- **Course**: Optimisation
- **Academic Year**: 2024-2025



---

**Keywords**: Optimization, Vehicle Routing, Bike Sharing, Simulated Annealing, Heuristics, Julia, Operations Research