# Mathematical problem definition

## Overview and assumptions

The mathematical model employed by RELOG is based on three main components:

1. **Products and Materials:** Inputs and outputs for both manufacturing and
   recycling plants. This includes raw materials, whether virgin or recovered,
   and final products, whether new or at their end-of-life. Each product has
   associated transportation parameters, such as costs, energy and emissions.

2. **Manufacturing and Recycling Plants:** Facilities that take in specific
   materials and produce certain products. The outputs can be sent to another
   plant for further processing, to a collection & distribution center for
   customer sale, or simply disposed of at landfill. Plants have associated
   costs (capital, fixed and operating), as well as various limits (processing
   capacity, storage and disposal limits).

3. **Collection and Distribution Centers:** Facilities that receive final
   products from the plants, sell them to customers, and then collect them back
   once they reach their end-of-life. Collected products can either be sent to a
   plant for recycling or disposed of at a local landfill. Centers have
   associated revenue and various costs, such as operating cost, collection cost
   and disposal cost. The amount of material collected by a center can either be
   a fixed rate per year, or depend on the amount of product sold at the center
   in previous years.

!!! note

    - We assume that transportation costs, energy and emissions scale linearly with transportation distance and amount being transported. Distances between locations are calculated using either approximated driving distances (continental U.S. only) or straight-line distances.
    - Once a plant is opened, we assume that it remains open until the end of the planning horizon. Similarly, once a plant is expanded, its size cannot be reduced at a later time.
    - In addition to serving as a source of end-of-life products, centers can also serve as a source for virgin materials. In this case, the center does not receive any inputs from manufacturing or recycling plants, and it generates the desired material at a fixed rate. Collection cost, in this case, refers to the cost to produce the virgin material.
    - We assume that centers accept either no input product, or a single input product.

## Sets

| Symbol   | Description                                                                                                                                         |
| :------- | :-------------------------------------------------------------------------------------------------------------------------------------------------- |
| $C$      | Set of collection and distribution centers                                                                                                          |
| $P$      | Set of manufacturing and recycling plants                                                                                                           |
| $M$      | Set of products and materials                                                                                                                       |
| $G$      | Set of greenhouse gases                                                                                                                             |
| $M^+_u$  | Set of output products of plant/center $u$.                                                                                                         |
| $M^-_u$  | Set of input products of plant/center $u$.                                                                                                          |
| $T$      | Set of time periods in the planning horizon. We assume $T=\{1,\ldots,t^{max}\}.$                                                                    |
| $E$      | Set of transportation edges. Specifically, $(u,v,m) \in E$ if $m$ is an output of $u$ and an input of $v$, where $m \in M$ and $u, v \in P \cup C$. |
| $E^-(v)$ | Set of incoming edges for plant/center v. Specifically, edges $(u,m)$ such that $(u,v,m) \in E$.                                                    |
| $E^+(u)$ | Set of outgoing edges for plant/center u. Specifically, edges $(v,m)$ such that $(u,v,m) \in E$.                                                    |

## Constants

| Symbol                        | Description                                                                                                                                                                                                      | Unit           |
| :---------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------- |
| $K^{\text{dist}}_{uv}$        | Distance between plants/centers $u$ and $v$                                                                                                                                                                      | km             |
| $K^\text{cap-init}_p$         | Initial capacity of plant $p$                                                                                                                                                                                    | tonne          |
| $K^\text{cap-max}_p$          | Maximum capacity of plant $p$                                                                                                                                                                                    | tonne          |
| $K^\text{cap-min}_p$          | Minimum capacity of plant $p$                                                                                                                                                                                    | tonne          |
| $K^\text{disp-limit}_{mt}$    | Maximum amount of material $m$ that can be disposed of (globally) at time $t$                                                                                                                                    | tonne          |
| $K^\text{disp-limit}_{mut}$   | Maximum amount of material $m$ that can be disposed of at plant/center $u$ at time $t$                                                                                                                           | tonne          |
| $K^\text{em-limit}_{gt}$      | Maximum amount of greenhouse gas $g$ allowed to be emitted (globally) at time $t$                                                                                                                                | tonne          |
| $K^\text{em-plant}_{gpt}$     | Amount of greenhouse gas $g$ released by plant $p$ at time $t$ for each tonne of input material processed                                                                                                        | tonne/tonne    |
| $K^\text{em-tr}_{gmt}$        | Amount of greenhouse gas $g$ released by transporting 1 tonne of material $m$ over one km at time $t$                                                                                                            | tonne/km-tonne |
| $K^\text{mix}_{pmt}$          | If plant $p$ receives one tonne of input material at time $t$, then $K^\text{mix}_{pmt}$ is the amount of product $m$ in this mix. Must be between zero and one, and the sum of these amounts must equal to one. | tonne          |
| $K^\text{out-fix}_{cmt}$      | Fixed amount of material $m$ collected at center $c$ at time $t$                                                                                                                                                 | tonne          |
| $K^\text{out-var-len}_{cm}$   | Length of the $K^\text{out-var}_{c,m,*}$ vector.                                                                                                                                                                 | --             |
| $K^\text{out-var}_{cmi}$      | Factor used to calculate variable amount of material $m$ collected at center $c$. See `eq_z_collected` for more details.                                                                                         | --             |
| $K^\text{output}_{pmt}$       | Amount of material $m$ produced by plant $p$ at time $t$ for each tonne of input material processed                                                                                                              | tonne          |
| $K^\text{storage-limit}_{pm}$ | Maximum amount of material $m$ that can be stored at plant $p$ at any time                                                                                                                                       | tonne          |
| $R^\text{collect}_{cmt}$      | Cost of collecting material $m$ at center $c$ at time $t$                                                                                                                                                        | \$/tonne       |
| $R^\text{disp}_{umt}$         | Cost to dispose of material at plant/center $u$ at time $t$                                                                                                                                                      | \$/tonne       |
| $R^\text{em}_{gt}$            | Penalty cost per tonne of greenhouse gas $g$ emitted at time $t$                                                                                                                                                 | \$/tonne       |
| $R^\text{expand}_{pt}$        | Cost to increase capacity of plant $p$ at time $t$                                                                                                                                                               | \$/tonne       |
| $R^\text{fix-exp}_{pt}$       | Increase in fixed operational cost for plant $p$ at time $t$ for every additional tonne of capacity                                                                                                              | \$/tonne       |
| $R^\text{fix-min}_{pt}$       | Fixed operating cost for plant $p$ at time $t$ at minimum capacity                                                                                                                                               | \$             |
| $R^\text{fix}_{ct}$           | Fixed operating cost for center $c$ at time $t$                                                                                                                                                                  | \$             |
| $R^\text{open}_{pt}$          | Cost to open plant $p$ at time $t$, at minimum capacity                                                                                                                                                          | \$             |
| $R^\text{rev}_{ct}$           | Revenue for selling the input product of center $c$ at this center at time $t$                                                                                                                                   | \$/tonne       |
| $R^\text{storage}_{pmt}$      | Cost to store one tonne of material $m$ at plant $p$ at time $t$ for one year                                                                                                                                    | \$/tonne       |
| $R^\text{tr}_{mt}$            | Cost to send material $m$ at time $t$                                                                                                                                                                            | \$/km-tonne    |
| $R^\text{var}_{pt}$           | Cost to process one tonne of input material at plant $p$ at time $t$                                                                                                                                             | \$/tonne       |

## Decision variables

| Symbol                       | JuMP name                                    | Description                                                                                             | Unit   |
| :--------------------------- | :------------------------------------------- | :------------------------------------------------------------------------------------------------------ | :----- |
| $x_{pt}$                     | `x[p.name, t]`                               | One if plant $p$ is operational at time $t$                                                             | binary |
| $y_{uvmt}$                   | `y[u.name, v.name, m.name, t]`               | Amount of product $m$ sent from plant/center $u$ to plant/center $v$ at time $t$                        | tonne  |
| $z^{\text{exp}}_{pt}$        | `z_exp[p.name, t]`                           | Extra capacity installed at plant $p$ at time $t$ above the minimum capacity                            | tonne  |
| $z^{\text{collected}}_{cmt}$ | `z_collected[c.name, m.name, t]`             | Amount of material $m$ collected by center $c$ at time $t$                                              | tonne  |
| $z^{\text{disp}}_{umt}$      | `z_disp[u.name, m.name, t]`                  | Amount of product $m$ disposed of at plant/center $u$ at time $t$                                       | tonne  |
| $z^{\text{em-plant}}_{gpt}$  | `z_em_plant[g.name, p.name, t]`              | Amount of greenhouse gas $g$ released by plant $p$ at time $t$                                          | tonne  |
| $z^{\text{em-tr}}_{guvmt}$   | `z_em_tr[g.name, u.name, v.name, m.name, t]` | Amount of greenhouse gas $g$ released at time $t$ due to transportation of material $m$ from $u$ to $v$ | tonne  |
| $z^{\text{input}}_{ut}$      | `z_input[u.name, t]`                         | Total amount received by plant/center $u$ at time $t$                                                   | tonne  |
| $z^{\text{prod}}_{umt}$      | `z_prod[u.name, m.name, t]`                  | Amount of product $m$ produced by plant/center $u$ at time $t$                                          | tonne  |
| $z^{\text{storage}}_{pmt}$   | `z_storage[p.name, m.name, t]`               | Amount of input material $m$ stored at plant $p$ at the end of time $t$                                 | tonne  |
| $z^{\text{process}}_{pt}$    | `z_process[p.name, t]`                       | Total amount of input material processed by plant $p$ at time $t$                                       | tonne  |

## Objective function

The goal is to minimize a linear objective function with the following terms:

- Transportation costs, which depend on transportation distance
  $K^{\text{dist}}_{uv}$ and product-specific factor $R^\text{tr}_{mt}$:

```math
\sum_{(u, v, m) \in E} \sum_{t \in T} K^{\text{dist}}_{uv} R^\text{tr}_{mt} y_{uvmt}
```

- Center revenue, obtained by selling products received from manufacturing and
  recycling plants:

```math
- \sum_{c \in C} \sum_{(p,m) \in E^-(c)} \sum_{t \in T} R^\text{rev}_{ct} y_{pcmt}
```

- Center collection cost, incurred for each tonne of output material sent to a
  plant:

```math
\sum_{c \in C} \sum_{(p,m) \in E^+(c)} \sum_{t \in T} R^\text{collect}_{cmt} y_{cpmt}
```

- Center disposal cost, incurred when disposing of output material, instead of
  sending it to a plant:

```math
\sum_{c \in C} \sum_{m \in M^+_c} \sum_{t \in T} R^\text{disp}_{cmt} z^\text{disp}_{cmt}
```

- Center fixed operating cost, incurred for every time period, regardless of
  input or output amounts:

```math
\sum_{c \in C} \sum_{t \in T} R^\text{fix}_{ct}
```

- Plant disposal cost, incurred for each tonne of product discarded at the
  plant:

```math
\sum_{p \in P} \sum_{m \in M^+_p} \sum_{t \in T} R^\text{disp}_{pmt} z^\text{disp}_{pmt}
```

- Plant opening cost, incurred when the plant goes from non-operational at time
  $t-1$ to operational at time $t$. Never incurred if the plant is initially
  open:

```math
\sum_{p \in P} \sum_{t \in T} R^\text{open}_{pt} \left(
  x_{pt} - x_{p,t-1}
\right)
```

- Plant fixed operating cost, incurred for every time period, regardless of
  input or output amounts, as long as the plant is operational. Depends on the
  size of the plant:

```math
\sum_{p \in P} \sum_{t \in T} \left(
    R^\text{fix-min}_{pt} x_{pt} +
    R^\text{fix-exp}_{pt} z^\text{exp}_{pt}
\right)
```

- Plant expansion cost, incurred whenever plant capacity increases:

```math
\sum_{p \in P} \sum_{t \in T} R^\text{expand}_{pt} \left(z^\text{exp}_{pt} - z^\text{exp}_{p,t-1} \right)
```

- Plant variable operating cost, incurred for each tonne of input material
  received by the plant:

```math
\sum_{p \in P} \sum_{(u,m) \in E^-(p)} \sum_{t \in T} R^\text{var}_{pt} y_{upmt}
```

- Plant storage cost, incurred for each tonne of material stored at the plant:

```math
\sum_{p \in P} \sum_{m \in M^-_p} \sum_{t \in T} R^\text{storage}_{pmt} z^{\text{storage}}_{pmt}
```

- Emissions penalty cost, incurred for each tonne of greenhouse gas emitted:

```math
\sum_{g \in G} \sum_{t \in T} R^\text{em}_{gt} \left(
  \sum_{p \in P} z^{\text{em-plant}}_{gpt} + \sum_{(u,v,m) \in E} z^{\text{em-tr}}_{guvmt}
\right)
```

## Constraints

- Definition of plant input (`eq_z_input[p.name, t]`):

```math
\begin{align*}
& z^{\text{input}}_{pt} = \sum_{(u,m) \in E^-(p)} y_{upmt}
& \forall p \in P, t \in T
\end{align*}
```

- Definition of plant processing (`eq_z_process[p.name, t]`):

```math
\begin{align*}
& z^{\text{process}}_{pt} = z^{\text{input}}_{pt} + \sum_{m \in M^-_p} \left(z^{\text{storage}}_{p,m,t-1} - z^{\text{storage}}_{pmt}\right)
& \forall p \in P, t \in T
\end{align*}
```

- Plant processing mix must have correct proportion
  (`eq_process_mix[p.name, m.name, t]`):

```math
\begin{align*}
& \sum_{u : (u,m) \in E^-(p)} y_{upmt} + z^{\text{storage}}_{p,m,t-1} - z^{\text{storage}}_{pmt}
= K^\text{mix}_{pmt} z^{\text{process}}_{pt}
& \forall p \in P, m \in M^-_p, t \in T
\end{align*}
```

- Definition of amount produced by a plant (`eq_z_prod[p.name, m.name, t]`):

```math
\begin{align*}
& z^\text{prod}_{pmt} = K^\text{output}_{pmt} z^{\text{process}}_{pt}
& \forall p \in P, m \in M^+_p, t \in T
\end{align*}
```

- Material produced by a plant must be sent somewhere or disposed of
  (`eq_balance[p.name, m.name, t]`):

```math
\begin{align*}
& z^\text{prod}_{pmt} = \sum_{v : (v,m) \in E^+(p)} y_{pvmt} + z^\text{disp}_{pmt}
& \forall p \in P, m \in M^+_p, t \in T
\end{align*}
```

- Plant can only be expanded if the plant is open, and up to a certain amount
  (`eq_exp_ub[p.name, t]`):

```math
\begin{align*}
& z^\text{exp}_{pt} \leq \left(K^\text{cap-max}_p - K^\text{cap-min}_p) x_{pt}
& \forall p \in P, t \in T
\end{align*}
```

- Plant is initially open if initial capacity is positive:

```math
\begin{align*}
& x_{p,0} = \begin{cases}
    0 & \text{ if } K^\text{cap-init}_p = 0 \\
    1 & \text{otherwise}
\end{cases}
& \forall p \in P
\end{align*}
```

- Calculation of initial plant expansion:

```math
\begin{align*}
& z^\text{exp}_{p,0} = K^\text{cap-init}_p - K^\text{cap-min}_p
& \forall p \in P
\end{align*}
```

- Plants cannot process more than their current capacity
  (`eq_process_limit[p.name,t]`)

```math
\begin{align*}
& z^\text{process}_{pt} \leq K^\text{cap-min}_p x_{pt} + z^\text{exp}_{pt}
& \forall p \in P, t \in T
\end{align*}
```

- Storage limit at the plants (`eq_storage_limit[p.name, m.name, t]`):

```math
\begin{align*}
& z^{\text{storage}}_{pmt} \leq K^\text{storage-limit}_{pm}
& \forall p \in P, m \in M^-_p, t \in T
\end{align*}
```

- Disposal limit at the plants (`eq_disposal_limit[p.name, m.name, t]`):

```math
\begin{align*}
& z^\text{disp}_{pmt} \leq K^\text{disp-limit}_{pmt}
& \forall p \in P, m \in M^+_p, t \in T
\end{align*}
```

- Once a plant is built, it must remain open until the end of the planning
  horizon (`eq_keep_open[p.name, t]`):

```math
\begin{align*}
& x_{pt} \geq x_{p,t-1}
& \forall p \in P, t \in T
\end{align*}
```

- Definition of center input (`eq_z_input[c.name, t]`):

```math
\begin{align*}
& z^\text{input}_{ct} = \sum_{u : (u,m) \in E^-(c)} y_{ucmt}
& \forall c \in C, t \in T
\end{align*}
```

- Calculation of amount collected by the center
  (`eq_z_collected[c.name, m.name, t]`). In the equation below,
  $K^\text{out-var-len}$ is the length of the $K^\text{out-var}_{c,m,*}$ vector.

```math
\begin{align*}
& z^\text{collected}_{cmt}
  = \sum_{i=0}^{\min\{K^\text{out-var-len}_{cm}-1,t-1\}} K^\text{out-var}_{c,m,i+1} z^\text{input}_{c,t-i}
  + K^\text{out-fix}_{cmt}
& \forall c \in C, m \in M^+_c, t \in T
\end{align*}
```

- Products collected at centers must be sent somewhere or disposed of
  (`eq_balance[c.name, m.name, t]`):

```math
\begin{align*}
& z^\text{collected}_{cmt} = \sum_{v : (v,m) \in E^+(c)} y_{cvmt} + z^\text{disp}_{cmt}
& \forall c \in C, m \in M^+_c, t \in T
\end{align*}
```

- Disposal limit at the centers (`eq_disposal_limit[c.name, m.name, t]`):

```math
\begin{align*}
& z^\text{disp}_{cmt} \leq K^\text{disp-limit}_{cmt}
& \forall c \in C, m \in M^+_c, t \in T
\end{align*}
```

- Global disposal limit (`eq_disposal_limit[m.name, t]`)

```math
\begin{align*}
& \sum_{p \in P} z^\text{disp}_{pmt} + \sum_{c \in C} z^\text{disp}_{cmt} \leq K^\text{disp-limit}_{mt}
& \forall m \in M, t \in T
\end{align*}
```

- Computation of transportation emissions
  (`eq_emission_tr[g.name, u.name, v.name, m.name, t]`):

```math
\begin{align*}
& z^{\text{em-tr}}_{guvmt} = K^{\text{dist}}_{uv} K^\text{em-tr}_{gmt} y_{uvmt}
& \forall g \in G, (u, v, m) \in E, t \in T
\end{align*}
```

- Computation of plant emissions (`eq_emission_plant[g.name, p.name, t]`):

```math
\begin{align*}
& z^{\text{em-plant}}_{gpt} = K^\text{em-plant}_{gpt} z^{\text{process}}_{pt}
& \forall g \in G, p \in P, t \in T
\end{align*}
```

- Global emissions limit (`eq_emission_limit[g.name, t]`):

```math
\begin{align*}
& \sum_{p \in P} z^{\text{em-plant}}_{gpt} + \sum_{(u,v,m) \in E} z^{\text{em-tr}}_{guvmt} \leq K^\text{em-limit}_{gt}
& \forall g \in G, t \in T
\end{align*}
```

- All stored materials must be processed by the end of the time horizon
  (`eq_storage_final[p.name, m.name]`):

```math
\begin{align*}
& z^{\text{storage}}_{p,m,t^{max}} = 0
& \forall p \in P, m \in M^-_p
\end{align*}
```

- Initial storage is zero (`eq_storage_initial[p.name, m.name]`):

```math
\begin{align*}
& z^{\text{storage}}_{p,m,0} = 0
& \forall p \in P, m \in M^-_p
\end{align*}
```
