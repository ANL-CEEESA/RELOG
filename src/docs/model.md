# Optimization Model

In this page, we describe the precise mathematical optimization model used by RELOG to find the optimal logistics plan. This model is a variation of the classical Facility Location Problem, which has been widely studied in the operations research literature. To simplify the exposition, we present the simplified case where there is only one type of plant.

## Mathematical Description

### Sets

* $L$ - Set of locations holding the original material to be recycled
* $M$ - Set of materials recovered during the reverse manufacturing process
* $P$ - Set of potential plants to open
* $T = \{ 1, \ldots, t^{max} \} $ - Set of time periods

### Constants

**Plants:**

* $c^\text{disp}_{pmt}$ - Cost of disposing one tonne of material $m$ at plant $p$ during time $t$ (`$/tonne/km`)
* $c^\text{exp}_{pt}$ - Cost of adding one tonne of capacity to plant $p$ at time $t$ (`$/tonne`)
* $c^\text{open}_{pt}$ - Cost of opening plant $p$ at time $t$, at minimum capacity (`$`)
* $c^\text{f-base}_{pt}$ - Fixed cost of keeping plant $p$ open during time period $t$ (`$`)
* $c^\text{f-exp}_{pt}$ - Increase in fixed cost for each additional tonne of capacity (`$/tonne`)
* $c^\text{var}_{pt}$ - Variable cost of processing one tonne of input at plant $p$ at time $t$ (`$/tonne`)
* $m^\text{min}_p$ - Minimum capacity of plant $p$ (`tonne`)
* $m^\text{max}_p$ - Maximum capacity of plant $p$ (`tonne`)
* $m^\text{disp}_{pmt}$ - Maximum amount of material $m$ that plant $p$ can dispose of during time $t$ (`tonne`)

**Products:**

* $\alpha_{pm}$ - Amount of material $m$ recovered by plant $t$ for each tonne of original material (`tonne/tonne`)
* $m^\text{initial}_{lt}$ - Amount of original material to be recycled at location $l$ during time $t$ (`tonne`)

**Transportation:**

* $c^\text{tr}_{t}$ - Transportation cost during time $t$ (`$/tonne/km`)
* $d_{lp}$ - Distance between plant $p$ and location $l$ (`km`)


### Decision variables
* $q_{mpt}$ - Amount of material $m$ recovered by plant $p$ during time $t$ (`tonne`)
* $u_{pt}$ - Binary variable that equals 1 if plant $p$ starts operating at time $t$ (`bool`)
* $w_{pt}$ - Extra capacity (amount above the minimum) added to plant $p$ during time $t$ (`tonne`)
* $x_{pt}$ - Binary variable that equals 1 if plant $p$ is operational at time $t$ (`bool`)
* $y_{lpt}$ - Amount of product sent from location $l$ to plant $p$ during time $t$ (`tonne`)
* $z_{mpt}$ - Amount of material $m$ disposed of by plant $p$ during time $t$ (`tonne`)


### Objective function

RELOG minimizes the overall capital, production and transportation costs:

\begin{align*}
    \text{minimize} \;\; &
        \sum_{t \in T} \sum_{p \in P} \left[
                c^\text{open}_{pt} u_{pt} +
                c^\text{f-base}_{pt} x_{pt} +
                \sum_{i=1}^t c^\text{f-exp}_{pt} w_{pi} +
                c^{\text{exp}}_{pt} w_{pt}
            \right] + \\
    &
        \sum_{t \in T} \sum_{l \in L} \sum_{p \in P} \left[
            c^{\text{tr}}_t d_{lp} + c^{\text{var}}_{pt}
        \right]  y_{lpt} + \\
    &
        \sum_{t \in T} \sum_{p \in P} \sum_{m \in M} c^{\text{disp}}_{pmt} z_{pmt}
\end{align*}

In the first line, we have (i) opening costs, if plant starts operating at time $t$, (ii) fixed operating costs, if plant is operational, (iii) additional fixed operating costs coming from expansion performed in all previous time periods up to the current one, and finally (iv) the expansion costs during the current time period.
In the second line, we have the transportation costs and the variable operating costs.
In the third line, we have the disposal costs.

### Constraints

* All original materials must be sent to a plant:

\begin{align}
    & \sum_{p \in P} y_{lpt} = m^\text{initial}_{lt} 
        & \forall l \in L, t \in T
\end{align}

* Plants have a limited capacity:

\begin{align}
    & \sum_{l \in L} y_{lpt} \leq m^\text{base}_p x_p + \sum_{i=1}^t w_p
        & \forall p \in P, t \in T
\end{align}

* Plants can only be expanded up to their maximum capacity. Furthermore, if a plant is closed, it cannot be expanded:

\begin{align}
    & \sum_{i=1}^t w_p \leq m^\text{max}_p x_p
        & \forall p \in P, t \in T
\end{align}

* Amount of recovered material is proportional to the plant input: 

\begin{align}
    & q_{mpt} = \alpha_{pm} \sum_{l \in L} y_{lpt}
        & \forall m \in M, p \in P, t \in T
\end{align}

* Because we only consider a single type of plant, all recovered material must be immediately disposed of. In RELOG's full model, recovered materials may be sent to another plant for further processing.

\begin{align}
    & q_{mpt} = z_{mpt}
        & \forall m \in M, p \in P, t \in T
\end{align}

* A plant is operation at time $t$ if it was operational at time $t-1$ or it was built at time $t$. This constraint also prevents a plant from being built multiple times.

\begin{align}
    & x_{pt} = x_{p,t-1} + u_{pt}
        & \forall p \in P, t \in T \setminus \{1\} \\
    & x_{p,1} = u_{p,1}
        & \forall p \in P
\end{align}


* Variable bounds:

\begin{align}
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
    & m^\text{disp}_{mpt} \geq z_{mpt} \geq 0
        & \forall m \in M, p \in P, t \in T
\end{align}

### Complete optimization model

\begin{align*}
    \text{minimize} \;\; &
        \sum_{t \in T} \sum_{p \in P} \left[
                c^\text{open}_{pt} u_{pt} +
                c^\text{f-base}_{pt} x_{pt} +
                \sum_{i=1}^t c^\text{f-exp}_{pt} w_{pi} +
                c^{\text{exp}}_{pt} w_{pt}
            \right] + \\
    &
        \sum_{t \in T} \sum_{l \in L} \sum_{p \in P} \left[
            c^{\text{tr}}_t d_{lp} + c^{\text{var}}_{pt}
        \right]  y_{lpt} + \\
    &
        \sum_{t \in T} \sum_{p \in P} \sum_{m \in M} c^{\text{disp}}_{pmt} z_{pmt} \\
    \text{subject to } & \sum_{p \in P} y_{lpt} = m^\text{initial}_{lt} 
        & \forall l \in L, t \in T \\
    & \sum_{l \in L} y_{lpt} \leq m^\text{base}_p x_p + \sum_{i=1}^t w_p
        & \forall p \in P, t \in T \\
    & \sum_{i=1}^t w_p \leq m^\text{max}_p x_p
        & \forall p \in P, t \in T \\
    & q_{mpt} = \alpha_{pm} \sum_{l \in L} y_{lpt}
        & \forall m \in M, p \in P, t \in T \\
    & q_{mpt} = z_{mpt}
        & \forall m \in M, p \in P, t \in T \\
    & x_{pt} = x_{p,t-1} + u_{pt}
        & \forall p \in P, t \in T \setminus \{1\} \\
    & x_{p,1} = u_{p,1}
        & \forall p \in P \\
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
    & m^\text{disp}_{mpt} \geq z_{mpt} \geq 0
        & \forall m \in M, p \in P, t \in T
\end{align*}
