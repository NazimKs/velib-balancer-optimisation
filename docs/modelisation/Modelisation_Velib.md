# Modélisation Complète du Problème Vélib

## 1. Éléments de Base

### Données d'entrée :
- **$n$** : nombre de stations
- **$K$** : capacité du camion
- **$nbvp_i$** : vélos présents initialement à la station $i$
- **$cap_i$** : capacité de la station $i$
- **$ideal_i$** : nombre idéal de vélos pour la station $i$
- **$d_{ik}$** : distance entre stations $i$ et $k$ (arrondie à l'entier le plus proche)

## 2. Variables de Décision

### a) Variables Principales

| Variable | Type | Domaine | Description |
|----------|------|---------|-------------|
| $x_{ij}$ | Binaire | {0,1} | 1 ssi station $i$ est visitée en position $j$ |
| $charge_j$ | Entier | [0,$K$] | Nombre de vélos dans le camion (charge_0 libre, charge_n=retour) |
| $depot_{ij}$ | Entier | [-$cap_i$, $cap_i$] | Vélos déposés/retirés à station $i$ à étape $j$ |

### b) Variables Auxiliaires

| Variable | Type | Rôle |
|----------|------|------|
| $d_i^+$ | Réel ≥0 | Excédent par rapport à l'idéal |
| $d_i^-$ | Réel ≥0 | Déficit par rapport à l'idéal |
| $y_{ijk}$ | Binaire | Produit $x_{ij} \times x_{k,j+1}$ pour linéarisation |

## 3. Contraintes Détaillées

### a) Contraintes de Routage

```math
\begin{cases}
\sum_{j=1}^n x_{ij} = 1 & \forall i \in \{1,...,n\} \\
\sum_{i=1}^n x_{ij} = 1 & \forall j \in \{1,...,n\} \\
x_{ij} \in \{0,1\} & \forall i,j
\end{cases}
```

### b) Contraintes de Flux

```math
charge_j = charge_{j-1} - \sum_{i=1}^n depot_{ij} \cdot x_{ij} \quad \forall j \in \{1,...,n\}
```

**Cas particuliers** :
- $charge_0$ : chargement initial au magasin (variable libre)
- $charge_n$ : vélos restants au retour au magasin
- $d_{0i}$ : distance magasin → station $i$
- $d_{i0}$ : distance station $i$ → magasin

### c) Contraintes de Capacité

```math
\begin{cases}
0 \leq charge_j \leq K & \forall j \\
nbvp_i + \sum_{j=1}^n depot_{ij} \leq cap_i & \forall i \\
\sum_{j=1}^n depot_{ij} \geq -nbvp_i & \forall i
\end{cases}
```

## 4. Fonction Objective du problème (Approche Lexicographique)

### Premier Niveau : Minimiser le Déséquilibre Global
```math
\min \quad d^* = \sum_{i=1}^n (d_i^+ + d_i^-)
```

### Deuxième Niveau : Minimiser la Distance parmi les solutions optimales
```math
\min \quad D = \sum_{j=1}^{n-1} \sum_{i=1}^n \sum_{k=1}^n x_{ij} x_{k,j+1} d_{ik} + \sum_{i=1}^n x_{i1} d_{0i} + \sum_{i=1}^n x_{in} d_{i0}
```

sous la contrainte additionnelle :
```math
\sum_{i=1}^n (d_i^+ + d_i^-) = d^*
```

où $d^*$ est la valeur optimale obtenue au premier niveau.

### Notes d'Implémentation
L'approche lexicographique nécessite une résolution en deux étapes :
1. D'abord minimiser le déséquilibre global pour trouver d*
2. Puis minimiser la distance parmi les solutions ayant d* comme déséquilibre



## 5. Linéarisation du problème

### a) Substitution des Termes Quadratiques

Pour chaque triplet $(i,j,k)$ avec $j ∈ {1,...,n-1}$ :

```math
\begin{cases}
y_{ijk} \leq x_{ij} \\
y_{ijk} \leq x_{k,j+1} \\
y_{ijk} \geq x_{ij} + x_{k,j+1} - 1 \\
y_{ijk} \geq 0
\end{cases}
```

### b) Formulation Linéaire pour l'Approche Lexicographique

**Première Étape (Déséquilibre) :**
```math
\min \sum_i (d_i^+ + d_i^-)
```

**Deuxième Étape (Distance) :**
```math
\min \left[\sum_{i,k,j} y_{ijk} d_{ik} + \sum_i (x_{i1} d_{0i} + x_{in} d_{i0})\right]
```
sous la contrainte :
```math
\sum_i (d_i^+ + d_i^-) = d^*
```

### c) Variables de Linéarisation
Les variables $y_{ijk}$ remplacent les produits $x_{ij}x_{k,j+1}$ dans le calcul de la distance totale.
