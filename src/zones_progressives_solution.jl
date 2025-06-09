# heuristique_zones_progressives.jl
# Heuristique de Balancement Progressif par Zones
# Une approche originale qui divise l'espace en zones et optimise progressivement

using Random
using Printf

# Réutilisation des structures du recuit simulé
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

# Zone géographique contenant des stations
struct Zone
    id::Int
    stations::Vector{Int}  # IDs des stations dans cette zone
    center::Tuple{Float64,Float64}
    priority::Float64  # Priorité basée sur le déséquilibre total de la zone
end

"""
    read_instance(filename::String) -> Instance
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
                continue
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
"""
function euclidean_distance(a::Tuple{Float64,Float64}, b::Tuple{Float64,Float64})
    return round(sqrt((a[1]-b[1])^2 + (a[2]-b[2])^2))
end

"""
    evaluate_solution(instance, route) -> (imbalance, distance, penalty)
"""
function evaluate_solution(instance::Instance, route::Vector{Int})
    current_charge = instance.K
    total_imbalance = 0.0
    penalty = 0.0
    stations_dict = Dict(s.id => s for s in instance.stations)
    
    for sid in route
        s = stations_dict[sid]
        desired = s.ideal - s.nbp
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
            penalty += (final_count - s.cap) * 1e6
        elseif final_count < 0
            penalty += abs(final_count) * 1e6
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

"""
    create_adaptive_zones(instance::Instance, num_zones::Int) -> Vector{Zone}
    
Crée des zones adaptatives basées sur la densité de déséquilibre et la proximité géographique.
"""
function create_adaptive_zones(instance::Instance, num_zones::Int)
    stations = instance.stations
    n = length(stations)
    
    # Si peu de stations, créer une zone par station
    if n <= num_zones
        zones = Zone[]
        for (i, s) in enumerate(stations)
            imbalance = abs(s.ideal - s.nbp)
            push!(zones, Zone(i, [s.id], (s.x, s.y), imbalance))
        end
        return zones
    end
    
    # Algorithme de clustering adaptatif basé sur le déséquilibre et la position
    zones = Zone[]
    used_stations = Set{Int}()
    
    # Étape 1: Identifier les stations avec le plus grand déséquilibre comme centres de zones
    station_imbalances = [(i, abs(s.ideal - s.nbp), s) for (i, s) in enumerate(stations)]
    sort!(station_imbalances, by=x->x[2], rev=true)
    
    zone_centers = []
    for i in 1:min(num_zones, n)
        _, _, center_station = station_imbalances[i]
        push!(zone_centers, center_station)
    end
    
    # Étape 2: Assigner chaque station à la zone la plus appropriée
    for zone_id in 1:length(zone_centers)
        center = zone_centers[zone_id]
        zone_stations = [center.id]
        push!(used_stations, center.id)
        
        # Calculer la priorité initiale de la zone
        zone_priority = abs(center.ideal - center.nbp)
        
        push!(zones, Zone(zone_id, zone_stations, (center.x, center.y), zone_priority))
    end
    
    # Assigner les stations restantes aux zones les plus proches
    for s in stations
        if s.id ∉ used_stations
            best_zone_id = 1
            best_score = Inf
            
            for (zone_id, zone) in enumerate(zones)
                # Score combinant distance et compatibilité de déséquilibre
                distance = euclidean_distance((s.x, s.y), zone.center)
                imbalance_compatibility = abs(abs(s.ideal - s.nbp) - zone.priority / length(zone.stations))
                score = distance + 10 * imbalance_compatibility
                
                if score < best_score
                    best_score = score
                    best_zone_id = zone_id
                end
            end
            
            push!(zones[best_zone_id].stations, s.id)
            # Recalculer le centre et la priorité de la zone
            zone_stations_data = [st for st in stations if st.id in zones[best_zone_id].stations]
            avg_x = sum(st.x for st in zone_stations_data) / length(zone_stations_data)
            avg_y = sum(st.y for st in zone_stations_data) / length(zone_stations_data)
            total_imbalance = sum(abs(st.ideal - st.nbp) for st in zone_stations_data)
            
            zones[best_zone_id] = Zone(best_zone_id, zones[best_zone_id].stations, 
                                     (avg_x, avg_y), total_imbalance)
        end
    end
    
    # Trier les zones par priorité décroissante
    sort!(zones, by=z->z.priority, rev=true)
    
    return zones
end

"""
    optimize_zone_route(instance::Instance, zone_stations::Vector{Int},
                       entry_point::Tuple{Float64,Float64}, current_charge::Int) -> Vector{Int}
    
Optimise l'ordre de visite dans une zone en utilisant une heuristique plus sophistiquée.
"""
function optimize_zone_route(instance::Instance, zone_stations::Vector{Int},
                           entry_point::Tuple{Float64,Float64}, current_charge::Int)
    if length(zone_stations) <= 1
        return zone_stations
    end
    
    # Essayer plusieurs stratégies et prendre la meilleure
    strategies = [
        nearest_neighbor_with_balance,
        savings_algorithm_zone,
        two_opt_zone_optimization
    ]
    
    best_route = zone_stations
    best_distance = Inf
    
    for strategy in strategies
        route = strategy(instance, zone_stations, entry_point, current_charge)
        distance = calculate_zone_distance(instance, route, entry_point)
        
        if distance < best_distance
            best_distance = distance
            best_route = route
        end
    end
    
    return best_route
end

"""
    nearest_neighbor_with_balance(instance, zone_stations, entry_point, current_charge)
    
Plus proche voisin avec prise en compte du déséquilibre.
"""
function nearest_neighbor_with_balance(instance::Instance, zone_stations::Vector{Int},
                                     entry_point::Tuple{Float64,Float64}, current_charge::Int)
    stations_dict = Dict(s.id => s for s in instance.stations)
    route = Int[]
    remaining = Set(zone_stations)
    current_pos = entry_point
    charge = current_charge
    
    while !isempty(remaining)
        best_station = -1
        best_score = Inf
        
        for sid in remaining
            s = stations_dict[sid]
            distance = euclidean_distance(current_pos, (s.x, s.y))
            
            # Calculer l'urgence du déséquilibre
            desired = s.ideal - s.nbp
            urgency = abs(desired)
            
            # Calculer la faisabilité avec la charge actuelle
            feasibility = 1.0
            if desired > 0 && charge < desired
                feasibility = charge / max(1, desired)
            elseif desired < 0 && (instance.K - charge) < abs(desired)
                feasibility = (instance.K - charge) / max(1, abs(desired))
            end
            
            # Score privilégiant la distance avec bonus pour l'urgence
            score = distance * (1 + 0.1 / (1 + urgency * feasibility))
            
            if score < best_score
                best_score = score
                best_station = sid
            end
        end
        
        push!(route, best_station)
        delete!(remaining, best_station)
        
        s = stations_dict[best_station]
        current_pos = (s.x, s.y)
        
        # Simuler l'opération
        desired = s.ideal - s.nbp
        if desired > 0
            actual = min(charge, desired)
            charge -= actual
        elseif desired < 0
            actual = -min(instance.K - charge, abs(desired))
            charge -= actual
        end
    end
    
    return route
end

"""
    savings_algorithm_zone(instance, zone_stations, entry_point, current_charge)
    
Algorithme des économies adapté pour une zone.
"""
function savings_algorithm_zone(instance::Instance, zone_stations::Vector{Int},
                              entry_point::Tuple{Float64,Float64}, current_charge::Int)
    if length(zone_stations) <= 2
        return zone_stations
    end
    
    stations_dict = Dict(s.id => s for s in instance.stations)
    
    # Calculer les économies pour chaque paire de stations
    savings = []
    for i in 1:length(zone_stations)
        for j in (i+1):length(zone_stations)
            sid1, sid2 = zone_stations[i], zone_stations[j]
            s1, s2 = stations_dict[sid1], stations_dict[sid2]
            
            # Distance depuis le point d'entrée vers chaque station
            d_entry_1 = euclidean_distance(entry_point, (s1.x, s1.y))
            d_entry_2 = euclidean_distance(entry_point, (s2.x, s2.y))
            d_12 = euclidean_distance((s1.x, s1.y), (s2.x, s2.y))
            
            # Économie = distance évitée en reliant directement les stations
            saving = d_entry_1 + d_entry_2 - d_12
            push!(savings, (saving, sid1, sid2))
        end
    end
    
    # Trier par économie décroissante
    sort!(savings, by=x->x[1], rev=true)
    
    # Construire la route en utilisant les meilleures économies
    route = [zone_stations[1]]  # Commencer par une station
    used = Set([zone_stations[1]])
    
    for (saving, sid1, sid2) in savings
        if length(used) == length(zone_stations)
            break
        end
        
        # Essayer d'ajouter une connexion profitable
        if sid1 in used && sid2 ∉ used
            push!(route, sid2)
            push!(used, sid2)
        elseif sid2 in used && sid1 ∉ used
            push!(route, sid1)
            push!(used, sid1)
        end
    end
    
    # Ajouter les stations restantes
    for sid in zone_stations
        if sid ∉ used
            push!(route, sid)
        end
    end
    
    return route
end

"""
    two_opt_zone_optimization(instance, zone_stations, entry_point, current_charge)
    
Optimisation 2-opt pour une zone.
"""
function two_opt_zone_optimization(instance::Instance, zone_stations::Vector{Int},
                                 entry_point::Tuple{Float64,Float64}, current_charge::Int)
    route = copy(zone_stations)
    improved = true
    
    while improved
        improved = false
        best_distance = calculate_zone_distance(instance, route, entry_point)
        
        for i in 1:(length(route)-1)
            for j in (i+1):length(route)
                # Créer une nouvelle route avec inversion du segment [i, j]
                new_route = copy(route)
                reverse!(new_route, i, j)
                
                new_distance = calculate_zone_distance(instance, new_route, entry_point)
                
                if new_distance < best_distance
                    route = new_route
                    best_distance = new_distance
                    improved = true
                end
            end
        end
    end
    
    return route
end

"""
    calculate_zone_distance(instance, route, entry_point)
    
Calcule la distance totale pour une route dans une zone.
"""
function calculate_zone_distance(instance::Instance, route::Vector{Int}, entry_point::Tuple{Float64,Float64})
    if isempty(route)
        return 0.0
    end
    
    stations_dict = Dict(s.id => s for s in instance.stations)
    total_distance = 0.0
    
    # Distance du point d'entrée à la première station
    first_station = stations_dict[route[1]]
    total_distance += euclidean_distance(entry_point, (first_station.x, first_station.y))
    
    # Distances entre stations consécutives
    for i in 1:(length(route)-1)
        s1 = stations_dict[route[i]]
        s2 = stations_dict[route[i+1]]
        total_distance += euclidean_distance((s1.x, s1.y), (s2.x, s2.y))
    end
    
    return total_distance
end

"""
    progressive_zone_balancing(instance::Instance; num_zones::Int=4, 
                              improvement_iterations::Int=100) -> Vector{Int}
    
Heuristique principale de balancement progressif par zones.
"""
function progressive_zone_balancing(instance::Instance; num_zones::Int=4,
                                  improvement_iterations::Int=100)
    Random.seed!(42)  # Pour la reproductibilité
    
    # Étape 1: Créer les zones adaptatives
    zones = create_adaptive_zones(instance, num_zones)
    
    # Étape 2: Construire la route initiale zone par zone
    route = Int[]
    current_pos = instance.warehouse
    current_charge = instance.K
    
    for zone in zones
        # Optimiser l'ordre dans cette zone
        zone_route = optimize_zone_route(instance, zone.stations, current_pos, current_charge)
        append!(route, zone_route)
        
        # Mettre à jour la position et la charge après passage dans la zone
        if !isempty(zone_route)
            stations_dict = Dict(s.id => s for s in instance.stations)
            last_station = stations_dict[zone_route[end]]
            current_pos = (last_station.x, last_station.y)
            
            # Simuler les opérations dans cette zone
            for sid in zone_route
                s = stations_dict[sid]
                desired = s.ideal - s.nbp
                if desired > 0
                    actual = min(current_charge, desired)
                    current_charge -= actual
                elseif desired < 0
                    actual = -min(instance.K - current_charge, abs(desired))
                    current_charge -= actual
                end
            end
        end
    end
    
    # Étape 3: Amélioration locale par échanges adaptatifs
    best_route = copy(route)
    best_imbalance, best_distance, _ = evaluate_solution(instance, route)
    
    
    for iter in 1:improvement_iterations
        # Stratégie d'amélioration adaptative
        if iter <= improvement_iterations ÷ 3
            # Phase 1: Échanges locaux (stations adjacentes)
            improved_route = local_swap_improvement(instance, best_route)
        elseif iter <= 2 * improvement_iterations ÷ 3
            # Phase 2: Échanges inter-zones
            improved_route = inter_zone_improvement(instance, best_route, zones)
        else
            # Phase 3: Réorganisation de segments
            improved_route = segment_reorganization(instance, best_route)
        end
        
        imbalance, distance, penalty = evaluate_solution(instance, improved_route)
        
        # Acceptation lexicographique
        if (imbalance < best_imbalance) || 
           (abs(imbalance - best_imbalance) < 1e-6 && distance < best_distance)
            best_route = improved_route
            best_imbalance = imbalance
            best_distance = distance
        end
    end
    
    
    return best_route
end

"""
    local_swap_improvement(instance::Instance, route::Vector{Int}) -> Vector{Int}
    
Amélioration par échanges locaux de stations adjacentes.
"""
function local_swap_improvement(instance::Instance, route::Vector{Int})
    best_route = copy(route)
    best_imbalance, best_distance, _ = evaluate_solution(instance, route)
    
    for i in 1:(length(route)-1)
        new_route = copy(route)
        new_route[i], new_route[i+1] = new_route[i+1], new_route[i]
        
        imbalance, distance, _ = evaluate_solution(instance, new_route)
        
        if (imbalance < best_imbalance) || 
           (abs(imbalance - best_imbalance) < 1e-6 && distance < best_distance)
            best_route = new_route
            best_imbalance = imbalance
            best_distance = distance
        end
    end
    
    return best_route
end

"""
    inter_zone_improvement(instance::Instance, route::Vector{Int}, zones::Vector{Zone}) -> Vector{Int}
    
Amélioration par échanges entre zones différentes.
"""
function inter_zone_improvement(instance::Instance, route::Vector{Int}, zones::Vector{Zone})
    best_route = copy(route)
    best_imbalance, best_distance, _ = evaluate_solution(instance, route)
    
    # Créer un mapping station -> zone
    station_to_zone = Dict{Int,Int}()
    for (zone_id, zone) in enumerate(zones)
        for sid in zone.stations
            station_to_zone[sid] = zone_id
        end
    end
    
    for i in 1:length(route)
        for j in (i+2):length(route)  # Éviter les échanges adjacents
            # Vérifier si les stations sont dans des zones différentes
            if station_to_zone[route[i]] != station_to_zone[route[j]]
                new_route = copy(route)
                new_route[i], new_route[j] = new_route[j], new_route[i]
                
                imbalance, distance, _ = evaluate_solution(instance, new_route)
                
                if (imbalance < best_imbalance) || 
                   (abs(imbalance - best_imbalance) < 1e-6 && distance < best_distance)
                    best_route = new_route
                    best_imbalance = imbalance
                    best_distance = distance
                end
            end
        end
    end
    
    return best_route
end

"""
    segment_reorganization(instance::Instance, route::Vector{Int}) -> Vector{Int}
    
Amélioration par réorganisation de segments de la route.
"""
function segment_reorganization(instance::Instance, route::Vector{Int})
    best_route = copy(route)
    best_imbalance, best_distance, _ = evaluate_solution(instance, route)
    
    n = length(route)
    segment_size = max(2, n ÷ 4)  # Taille de segment adaptative
    
    for start in 1:(n-segment_size+1)
        segment_end = min(start + segment_size - 1, n)
        
        # Extraire le segment et le réorganiser
        segment = route[start:segment_end]
        
        # Essayer différentes permutations du segment (limiter pour éviter l'explosion combinatoire)
        max_attempts = min(10, length(segment) <= 8 ? factorial(length(segment)) : 40)
        for _ in 1:max_attempts
            shuffled_segment = shuffle(segment)
            
            new_route = copy(route)
            new_route[start:segment_end] = shuffled_segment
            
            imbalance, distance, _ = evaluate_solution(instance, new_route)
            
            if (imbalance < best_imbalance) || 
               (abs(imbalance - best_imbalance) < 1e-6 && distance < best_distance)
                best_route = new_route
                best_imbalance = imbalance
                best_distance = distance
            end
        end
    end
    
    return best_route
end

"""
    lexicographic_zone_optimization(instance::Instance) -> (Vector{Int}, Float64, Float64)
    
Optimisation lexicographique utilisant l'heuristique de zones progressives.
"""
function lexicographic_zone_optimization(instance::Instance)
    # Phase 1: Optimiser le déséquilibre
    num_zones = max(2, length(instance.stations) ÷ 3)  # Nombre de zones adaptatif
    route_phase1 = progressive_zone_balancing(instance, num_zones=num_zones,
                                            improvement_iterations=200)
    
    imbalance_phase1, distance_phase1, _ = evaluate_solution(instance, route_phase1)
    d_star = imbalance_phase1
    
    # Phase 2: Optimiser la distance en maintenant le déséquilibre optimal
    best_route = route_phase1
    best_distance = distance_phase1
    
    # Amélioration locale ciblée pour réduire la distance tout en gardant le même déséquilibre
    for attempt in 1:1e4  # Réduire le nombre d'essais
        current_route = copy(best_route)
        
        # Appliquer des améliorations locales spécifiques
        improved_route = local_distance_optimization(instance, current_route, d_star)
        
        imbalance, distance, _ = evaluate_solution(instance, improved_route)
        
        # Accepter seulement si le déséquilibre est optimal et la distance meilleure
        if abs(imbalance - d_star) < 1e-6 && distance < best_distance
            best_route = improved_route
            best_distance = distance
        end
    end
    
    return best_route, d_star, best_distance
end

"""
    local_distance_optimization(instance::Instance, route::Vector{Int}, target_imbalance::Float64) -> Vector{Int}
    
Optimisation locale pour réduire la distance tout en maintenant le déséquilibre cible.
"""
function local_distance_optimization(instance::Instance, route::Vector{Int}, target_imbalance::Float64)
    best_route = copy(route)
    best_distance = Inf
    
    # Vérifier que la route initiale a le bon déséquilibre
    imbalance, distance, _ = evaluate_solution(instance, route)
    if abs(imbalance - target_imbalance) < 1e-6
        best_distance = distance
    else
        return route  # Retourner la route originale si elle n'a pas le bon déséquilibre
    end
    
    # Essayer des échanges 2-opt pour améliorer la distance
    n = length(route)
    for i in 1:(n-2)
        for j in (i+2):n
            # Créer une nouvelle route avec inversion du segment [i+1, j]
            new_route = copy(route)
            reverse!(new_route, i+1, j)
            
            new_imbalance, new_distance, _ = evaluate_solution(instance, new_route)
            
            # Accepter si le déséquilibre est maintenu et la distance améliorée
            if abs(new_imbalance - target_imbalance) < 1e-6 && new_distance < best_distance
                best_route = new_route
                best_distance = new_distance
            end
        end
    end
    
    return best_route
end

"""
    simulate_route_with_details(instance, route) -> (details, total_imbalance, total_distance, return_distance, final_charge)
"""
function simulate_route_with_details(instance::Instance, route::Vector{Int})
    details = []
    current_charge = instance.K
    stations_dict = Dict(s.id => s for s in instance.stations)
    prev_location = instance.warehouse
    
    for (index, sid) in enumerate(route)
        d_travel = euclidean_distance(prev_location, (stations_dict[sid].x, stations_dict[sid].y))
        prev_location = (stations_dict[sid].x, stations_dict[sid].y)
        s = stations_dict[sid]
        desired = s.ideal - s.nbp
        init_charge = current_charge
        operation = 0
        
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
        
        push!(details, (order=index, station_id=s.id, desired=desired, status=status, 
                       operation=operation, init_charge=init_charge, post_charge=current_charge, 
                       distance=d_travel))
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
        best_route, d_star, best_distance = lexicographic_zone_optimization(instance)
        elapsed_time = time() - start_time
        
        println("\nSolution par heuristique de zones progressives:")
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