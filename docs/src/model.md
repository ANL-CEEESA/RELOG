# Optimization Model

In this page, we describe the precise mathematical optimization model used by RELOG to find the optimal logistics plan. This model is a variation of the classical Facility Location Problem, which has been widely studied in the operations research literature. To simplify the exposition, we present the simplified case where there is only one type of plant.

## Mathematical Description

### Sets

| Symbol                         | Description                                                           |
| :----------------------------- | :-------------------------------------------------------------------- |
| $L$                            | Set of collection centers holding the primary material to be recycled |
| $M$                            | Set of materials recovered during the reverse manufacturing process   |
| $P$                            | Set of potential plants to open                                       |
| $T = \{ 1, \ldots, t^{max} \}$ | Set of time periods                                                   |

### Constants

#### Plants

| Symbol                  | Description                                                                            | Unit        |
| :---------------------- | :------------------------------------------------------------------------------------- | :---------- |
| $c^\text{exp}_{pt}$     | Cost of adding one tonne of capacity to plant $p$ at time $t$                          | \$/tonne    |
| $c^\text{f-base}_{pt}$  | Fixed cost of keeping plant $p$ open during time period $t$                            | $           |
| $c^\text{f-exp}_{pt}$   | Increase in fixed cost for each additional tonne of capacity                           | \$/tonne    |
| $c^\text{open}_{pt}$    | Cost of opening plant $p$ at time $t$, at minimum capacity                             | $           |
| $c^\text{p-disp}_{pmt}$ | Cost of disposing recovered material $m$ at plant $p$ during time $t$                  | \$/tonne/km |
| $c^\text{store}_{pt}$   | Cost of storing primary material at plant $p$ at time $t$                              | \$/tonne    |
| $c^\text{proc}_{pt}$    | Variable cost of processing primary material at plant $p$ at time $t$                  | \$/tonne    |
| $m^\text{max}_p$        | Maximum capacity of plant $p$                                                          | tonne       |
| $m^\text{min}_p$        | Minimum capacity of plant $p$                                                          | tonne       |
| $m^\text{init}_p$       | Initial capacity of plant $p$                                                          | tonne       |
| $m^\text{p-disp}_{pmt}$ | Maximum amount of recovered material $m$ that plant $p$ can dispose of during time $t$ | tonne       |
| $m^\text{store}_p$      | Maximum amount of primary material that plant $p$ can store for later processing.      | tonne       |

#### Products

| Symbol                  | Description                                                                                              | Unit        |
| :---------------------- | :------------------------------------------------------------------------------------------------------- | :---------- |
| $\alpha_{pm}$           | Amount of material $m$ recovered by plant $t$ for each tonne of primary material                         | tonne/tonne |
| $c^\text{acq}_{lt}$     | Cost of acquiring primary material at collection center $l$ during time $t$                              | \$/tonne    |
| $c^\text{c-disp}_{lt}$  | Cost of disposing primary material at collection center $l$ during time $t$                              | \$/tonne    |
| $m^\text{c-disp}_{t}$   | Maximum amount of primary material that can be disposed of across all collection centers during time $t$ | tonne       |
| $m^\text{initial}_{lt}$ | Amount of primary material available to be recycled at collection center $l$ during time $t$             | tonne       |

#### Transportation

| Symbol            | Description                                          | Unit        |
| :---------------- | :--------------------------------------------------- | :---------- |
| $c^\text{tr}_{t}$ | Cost to transport primary material during time $t$   | \$/tonne/km |
| $d_{lp}$          | Distance between plant $p$ and collection center $l$ | km          |

### Decision variables

| Symbol                    | Description                                                                             | Unit    |
| :------------------------ | :-------------------------------------------------------------------------------------- | :------ |
| $q_{mpt}$                 | Amount of material $m$ recovered by plant $p$ during time $t$                           | tonne   |
| $u_{pt}$                  | Binary variable that equals 1 if plant $p$ starts operating at time $t$                 | Boolean |
| $w_{pt}$                  | Extra capacity (amount above the minimum) added to plant $p$ during time $t$            | tonne   |
| $x_{pt}$                  | Binary variable that equals 1 if plant $p$ is operational at time $t$                   | Boolean |
| $y_{lpt}$                 | Amount of primary material sent from collection center $l$ to plant $p$ during time $t$ | tonne   |
| $z^{\text{p-disp}}_{mpt}$ | Amount of recovered material $m$ disposed of by plant $p$ during time $t$               | tonne   |
| $z^{\text{c-disp}}_{lt}$  | Amount of primary material disposed of at collection center $l$ during time $t$         | tonne   |
| $z^{\text{store}}_{pt}$   | Amount of primary material in storage at plant $p$ by the end of time period $t$        | tonne   |
| $z^{\text{proc}}_{mpt}$   | Amount of primary material processed by plant $p$ during time period $t$                | tonne   |

### Objective function

RELOG minimizes the overall capital, production and transportation costs:

```math
\begin{align*}
    \text{minimize} \;\; &
        \sum_{t \in T} \sum_{p \in P} \left[
                c^\text{open}_{pt} u_{pt} +
                c^\text{f-base}_{pt} x_{pt} +
                c^\text{f-exp}_{pt}  \left( \sum_{i=0}^t w_{pi} \right) +
                c^{\text{exp}}_{pt} w_{pt}
            \right] + \\
    &
        \sum_{t \in T} \sum_{p \in P} \left[
                c^{\text{store}}_{pt} z^{\text{store}}_{pt} +
                c^{\text{proc}}_{pt} z^{\text{proc}}_{pt}
            \right] + \\
    &
        \sum_{t \in T} \sum_{l \in L} \sum_{p \in P}
            c^{\text{tr}}_t d_{lp} y_{lpt} +
        \\
    &
        \sum_{t \in T} \sum_{p \in P} \sum_{m \in M} c^{\text{p-disp}}_{pmt} z_{pmt} +
        \\
    &
        \sum_{t \in T} \sum_{l \in L} c^\text{acq}_{lt} \left(
            m^\text{initial}_{lt} - z^{\text{c-disp}}_{lt}
        \right) + c^\text{c-disp}_{lt} z^{\text{c-disp}}_{lt}
\end{align*}
```

In the first line, we have (i) opening costs, if plant starts operating at time $t$, (ii) fixed operating costs, if plant is operational, (iii) additional fixed operating costs coming from expansion performed in all previous time periods up to the current one, and finally (iv) the expansion costs during the current time period.
In the second line, we have storage and variable processing costs.
In the third line, we have transportation costs.
In the fourth line, we have disposal costs at the plants.
In the fifth line, we have acquisition and disposal cost at the collection centers.

### Constraints

- All primary material must either be sent to a plant for processing or disposed of at the collection center:

```math
\begin{align*}
    & \sum_{p \in P} y_{lpt} + z^{\text{c-disp}}_{lt} = m^\text{initial}_{lt}
        & \forall l \in L, t \in T
\end{align*}
```

- There is a limit on how much primary material can be disposed of at the collection centers:

```math
\begin{align*}
    & \sum_{l \in L} z^{\text{c-disp}}_{lt} \leq m^\text{c-disp}_{t}
        & t \in T
\end{align*}
```

- Amount received equals amount processed plus stored. Furthermore, all primary material should be processed by the end of the simulation.

```math
\begin{align*}
    & \sum_{l \in L} y_{lpt} + z^{\text{store}}_{p,t-1}
        = z^{\text{proc}}_{pt} + z^{\text{store}}_{p,t}
        & \forall p \in P, t \in T \\
    & z^{\text{store}}_{p,0} = 0
        & \forall p \in P \\
    & z^{\text{store}}_{p,t^{\max}} = 0
        & \forall p \in P
\end{align*}
```

- Plants have a limited processing capacity. Furthermore, if a plant is closed, it has zero processing capacity:

```math
\begin{align*}
    & z^{\text{proc}}_{pt} \leq m^\text{min}_p x_p + \sum_{i=0}^t w_p
        & \forall p \in P, t \in T
\end{align*}
```

- Plants have limited storage capacity. Furthermore, if a plant is closed, is has zero storage capacity:

```math
\begin{align*}
    & z^{\text{store}}_{pt} \leq m^\text{store}_p x_p
        & \forall p \in P, t \in T
\end{align*}
```

- Plants can only be expanded up to their maximum capacity. Furthermore, if a plant is closed, it cannot be expanded:

```math
\begin{align*}
    & \sum_{i=0}^t w_p \leq \left( m^\text{max}_p - m^\text{min}_p \right) x_p
        & \forall p \in P, t \in T
\end{align*}
```

- Amount of recovered material is proportional to amount processed:

```math
\begin{align*}
    & q_{mpt} = \alpha_{pm} z^{\text{proc}}_{pt}
        & \forall m \in M, p \in P, t \in T
\end{align*}
```

- Because we only consider a single type of plant, all recovered material must be immediately disposed of. In RELOG's full model, recovered materials may be sent to another plant for further processing.

```math
\begin{align*}
    & q_{mpt} = z^{\text{p-disp}}_{mpt}
        & \forall m \in M, p \in P, t \in T
\end{align*}
```

- A plant is operational at time $t$ if it was operational at time $t-1$ or it was built at time $t$. This constraint also prevents a plant from being built multiple times.

```math
\begin{align*}
    & x_{pt} = x_{p,t-1} + u_{pt}
        & \forall p \in P, t \in T \\
\end{align*}
```

- Boundary constants:

```math
\begin{align*}
    & x_{p,0} = \begin{cases}
        0 & \text{ if } m^\text{init}_p = 0 \\
        1 & \text{ otherwise }
    \end{cases} \\
    & w_{p,0} = \max\left\{0, m^\text{init}_p - m^\text{min}_p \right\}
\end{align*}
```

- Variable bounds:

```math
\begin{align*}
    & q_{mpt} \geq 0
        & \forall m \in M, p \in P, t \in T \\
    & u_{pt} \in \{0,1\}
        & \forall p \in P, t \in T \\
    & w_{pt} \geq 0
        & \forall p \in P, t \in T \\
    & x_{pt} \in \{0,1\}
        & \forall p \in P, t \in T \\
    & y_{lpt} \geq 0
        & \forall l \in L, p \in P, t \in T \\
    & z^{\text{c-disp}}_{lt} \geq 0
        & l \in L, t \in T \\
    & z^{\text{store}}_{pt} \geq 0
        & p \in P, t \in T \\
    & z^{\text{p-disp}}_{mpt}, z^{\text{proc}}_{mpt} \geq 0
        & \forall m \in M, p \in P, t \in T
\end{align*}
```
