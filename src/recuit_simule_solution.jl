# recuit_simule_solution_lex.jl

using Random
using Printf

# Définition des structures pour représenter une station et une instance
struct Station
    id::Int
    x::Float64
    y::Float64
    nbp::Int
    cap::Int
    ideal::Int
end

struct Instance
    name::String
    K::Int
    stations::Vector{Station}
    warehouse::Tuple{Float64,Float64}
end

"""
    read_instance(filename::String) -> Instance

Lit le fichier d’instance et en extrait :
- Le nom (après le mot clé "name")
- La capacité du camion (après "K")
- La liste des stations (après le mot clé "stations")
  avec pour chaque station les valeurs : id, x, y, nbp, cap, ideal
- Les coordonnées du magasin (ligne commençant par "warehouse")
"""
function read_instance(filename::String)::Instance
    open(filename, "r") do f
        lines = readlines(f)
        lines = [strip(l) for l in lines if !isempty(strip(l))]
        name = ""
        K = 0
        stations = Station[]
        warehouse = (0.0, 0.0)
        mode = ""
        for line in lines
            if startswith(lowercase(line), "name")
                parts = split(line)
                if length(parts) ≥ 2
                    name = parts[2]
                end
            elseif startswith(lowercase(line), "k")
                parts = split(line)
                if length(parts) ≥ 2
                    K = parse(Int, parts[2])
                end
            elseif lowercase(line) == "stations"
                mode = "stations"
            elseif startswith(lowercase(line), "warehouse")
                parts = split(line)
                if length(parts) ≥ 3
                    warehouse = (parse(Float64, parts[2]), parse(Float64, parts[3]))
                end
                mode = "done"
            elseif startswith(line, "#")
                continue  # ignorer les commentaires
            elseif mode == "stations"
                parts = split(line)
                if length(parts) ≥ 6
                    sid   = parse(Int, parts[1])
                    x     = parse(Float64, parts[2])
                    y     = parse(Float64, parts[3])
                    nbp   = parse(Int, parts[4])
                    cap   = parse(Int, parts[5])
                    ideal = parse(Int, parts[6])
                    push!(stations, Station(sid, x, y, nbp, cap, ideal))
                end
            end
        end
        return Instance(name, K, stations, warehouse)
    end
end

"""
    euclidean_distance(a, b) -> Float64

Calcule la distance euclidienne entre deux points a et b (chacun un tuple (x,y))
et arrondit au nombre entier le plus proche.
"""
function euclidean_distance(a::Tuple{Float64,Float64}, b::Tuple{Float64,Float64})
    return round(sqrt((a[1]-b[1])^2 + (a[2]-b[2])^2))
end

"""
    evaluate_solution(instance, route) -> (imbalance, distance)

Simule la tournée en appliquant les décisions de dépôt/retrait.
Le déséquilibre total est la somme des écarts absolus |desired - actual| pour chaque station.
"""
function evaluate_solution(instance::Instance, route::Vector{Int})
    current_charge = instance.K   # camion part plein
    total_imbalance = 0.0
    penalty = 0.0
    stations_dict = Dict(s.id => s for s in instance.stations)
    for sid in route
        s = stations_dict[sid]
        desired = s.ideal - s.nbp  # >0 : manque, <0 : excédent
        actual = 0
        if desired > 0
            actual = min(current_charge, desired)
            current_charge -= actual
        elseif desired < 0
            actual = -min(instance.K - current_charge, abs(desired))
            current_charge -= actual
        end
        total_imbalance += abs(desired - actual)
                final_count = s.nbp + actual
                if final_count > s.cap
                    penalty += (final_count - s.cap)*1e6
                elseif final_count < 0
                    penalty += abs(final_count)*1e6
                end
    end
    station_coords = Dict(s.id => (s.x, s.y) for s in instance.stations)
    total_distance = 0.0
    total_distance += euclidean_distance(instance.warehouse, station_coords[route[1]])
    for i in 1:(length(route)-1)
        total_distance += euclidean_distance(station_coords[route[i]], station_coords[route[i+1]])
    end
    total_distance += euclidean_distance(station_coords[route[end]], instance.warehouse)
    return total_imbalance, total_distance, penalty
end

# Fonction de coût pour la phase 1 (minimiser le déséquilibre global)
function cost_phase1(instance::Instance, route::Vector{Int})
    imbalance, _, penalty = evaluate_solution(instance, route)
    return imbalance + penalty
end

# Fonction de coût pour la phase 2 (minimiser la distance sous la contrainte d'équilibre optimal)
function cost_phase2(instance::Instance, route::Vector{Int}, dstar::Float64)
    imbalance, distance, penalty = evaluate_solution(instance, route)
    if abs(imbalance - dstar) > 1e-6
        return 1e12
    else
        return distance + penalty
    end
end

"""
    lexicographic_simulated_annealing(instance; max_iter_phase1, max_iter_phase2, initial_temp, cooling_rate)

Recherche par recuit simulé d’une solution en deux phases selon l'approche lexicographique dictée par la modélisation.
Phase 1 : Minimiser le déséquilibre global pour obtenir d*.
Phase 2 : Minimiser la distance parmi les solutions ayant un déséquilibre égal à d*.
"""
function lexicographic_simulated_annealing(instance::Instance; max_iter_phase1=1e7, max_iter_phase2=1e8, initial_temp=1000.0)
    Random.seed!(1234)
    # Phase 1 : Minimisation du déséquilibre
    route = shuffle([s.id for s in instance.stations])
    best_route_phase1 = copy(route)
    best_cost_phase1 = cost_phase1(instance, route)
    # Adaptive cooling: scale reference cooling_rate_ref=0.99995 from K_ref=6,N_ref=10 to any K,N
    K = instance.K
    N = length(instance.stations)
    cooling_rate_ref = 1 - 5e-6
    K_ref = 6
    N_ref = 10
    cooling_rate = exp(log(cooling_rate_ref) * (K_ref * N_ref) / (K * N))

    @printf("Cooling rate: %.9f\n", cooling_rate)
    current_temp = initial_temp

    for iter in 1:max_iter_phase1
        new_route = copy(route)
        i, j = rand(1:length(new_route), 2)
        new_route[i], new_route[j] = new_route[j], new_route[i]
        new_cost = cost_phase1(instance, new_route)
        Δ = new_cost - cost_phase1(instance, route)
        if Δ < 0 || exp(-Δ/current_temp) > rand()
            route = new_route
            if new_cost < best_cost_phase1
                best_cost_phase1 = new_cost
                best_route_phase1 = copy(route)
            end
        end
        current_temp *= cooling_rate
        if current_temp < 3e-2
            break
        end
    end

    d_star = best_cost_phase1
    @printf("Phase 1 terminée: déséquilibre optimal (d*) = %.2f\n", d_star)

    # Phase 2 : Minimisation de la distance en respectant la contrainte d'équilibre
    route = best_route_phase1
    best_route_phase2 = copy(route)
    best_cost_phase2 = cost_phase2(instance, route, d_star)
    current_temp = initial_temp

    for iter in 1:max_iter_phase2
        new_route = copy(route)
        i, j = rand(1:length(new_route), 2)
        new_route[i], new_route[j] = new_route[j], new_route[i]
        new_cost = cost_phase2(instance, new_route, d_star)
        # Pour la solution actuelle, extraire la distance si elle atteint l'équilibre optimal, sinon pénaliser.
        current_eval = evaluate_solution(instance, route)
        current_cost = (abs(current_eval[1] - d_star) < 1e-6) ? current_eval[2] : 1e12
        Δ = new_cost - current_cost

        if Δ < 0 || exp(-Δ/current_temp) > rand()
            route = new_route
            # Mettre à jour best si la solution atteint l'équilibre optimal et offre une distance réduite.
            eval_new = evaluate_solution(instance, new_route)
            if (abs(eval_new[1] - d_star) < 1e-6) && new_cost < best_cost_phase2
                best_cost_phase2 = new_cost
                best_route_phase2 = copy(new_route)
            end
        end
        current_temp *= cooling_rate
        if current_temp < 3e-2
            break
        end
    end

    return best_route_phase2, d_star, best_cost_phase2, evaluate_solution(instance, best_route_phase2)
end

"""
    simulate_route_with_details(instance, route) -> (details, total_imbalance, total_distance, return_distance, final_charge)

Simule la tournée étape par étape.
Pour chaque station, enregistre:
  - order: ordre de passage
  - station_id: identifiant de la station
  - desired: écart (s.ideal - s.nbp)
  - status: "manque", "excédent" ou "équilibrée"
  - operation: nombre de vélos déposés (positif) ou retirés (négatif)
  - init_charge: charge à l'arrivée sur la station (avant intervention)
  - post_charge: charge après intervention
  - distance: distance parcourue depuis le point précédent
Retourne également la distance du retour au dépôt et la charge finale.
"""
function simulate_route_with_details(instance::Instance, route::Vector{Int})
    details = []
    current_charge = instance.K  # camion part plein
    stations_dict = Dict(s.id => s for s in instance.stations)
    prev_location = instance.warehouse
    for (index, sid) in enumerate(route)
        d_travel = euclidean_distance(prev_location, (stations_dict[sid].x, stations_dict[sid].y))
        prev_location = (stations_dict[sid].x, stations_dict[sid].y)
        s = stations_dict[sid]
        desired = s.ideal - s.nbp  # >0 : manque, <0 : excédent
        init_charge = current_charge
        operation = 0  # nombre de vélos déposés/retrirés
        if desired == 0
            status = "équilibrée"
        elseif desired > 0
            status = "manque"
            operation = min(current_charge, desired)
            current_charge -= operation
        else
            status = "excédent"
            operation = -min(instance.K - current_charge, abs(desired))
            current_charge -= operation
        end
        push!(details, (order=index, station_id=s.id, desired=desired, status=status, operation=operation, init_charge=init_charge, post_charge=current_charge, distance=d_travel))
    end
    return_distance = euclidean_distance(prev_location, instance.warehouse)
    station_coords = Dict(s.id => (s.x, s.y) for s in instance.stations)
    total_distance = 0.0
    total_distance += euclidean_distance(instance.warehouse, station_coords[route[1]])
    for i in 1:(length(route)-1)
        total_distance += euclidean_distance(station_coords[route[i]], station_coords[route[i+1]])
    end
    total_distance += euclidean_distance(station_coords[route[end]], instance.warehouse)
    total_imbalance, _, _ = evaluate_solution(instance, route)
    final_charge = current_charge
    return details, total_imbalance, total_distance, return_distance, final_charge
end

"""
    print_details(details, return_distance, final_charge)

Affiche le détail de la tournée suivant le format demandé.
"""
function print_details(details, return_distance, final_charge)
    if length(details) > 0
        first = details[1]
        @printf("d = %d ; charge = %d\n", first.distance, first.init_charge)
    end
    for d in details
        desired_str = d.desired == 0 ? "équilibrée" : (d.desired > 0 ? "manque = " * string(d.desired) : "excédent = " * string(abs(d.desired)))
        op_str = d.operation == 0 ? "0" : (d.operation > 0 ? "+" * string(d.operation) : "-" * string(abs(d.operation)))
        @printf("%d: Station %d (%s) ; vélos deposés/retirés : %s\n", d.order, d.station_id, desired_str, op_str)
        @printf("d = %d ; charge = %d\n", d.distance, d.post_charge)
    end
    @printf("Retour au dépôt: d = %d ; charge = %d\n", return_distance, final_charge)
end

function main()
    instance_dir = "../instances"
    files = readdir(instance_dir)
    
    # Filtrer les fichiers .dat
    instance_files = filter(f -> endswith(f, ".dat"), files)
    
    for file in instance_files
        path = joinpath(instance_dir, file)
        println("\nTraitement de l'instance: $path")
        instance = read_instance(path)
        println("Instance: ", instance.name)
        println("Capacité du camion (K): ", instance.K)
        println("Nombre de stations: ", length(instance.stations))
        println("Coordonnées du magasin: ", instance.warehouse)
        
        # Mesurer le temps d'exécution
        start_time = time()
        best_route, d_star, best_distance, (final_imbalance, total_distance, penalty) = lexicographic_simulated_annealing(instance)
        elapsed_time = time() - start_time
        
        println("\nSolution par recuit simulé lexicographique:")
        println("Itinéraire optimal : ", best_route)
        @printf("Déséquilibre global (d*) : %.2f\n", d_star)
        
        details, total_imbalance, total_distance, return_distance, final_charge = simulate_route_with_details(instance, best_route)
        println("\nDétail de la tournée :")
        print_details(details, return_distance, final_charge)
        @printf("\nDéséquilibre total : %.2f\nDistance totale parcourue : %.2f\n", total_imbalance, total_distance)
        
        # Afficher le temps d'exécution
        @printf("Temps d'exécution: %.4f secondes\n", elapsed_time)
    end
end

main()