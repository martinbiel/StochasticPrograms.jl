# Quick start

## Installation

StochasticPrograms is not yet registered and is therefore installed as follows

```
pkg> add https://github.com/martinbiel/StochasticPrograms.jl
```

## A simple stochastic program

To showcase the use of StochasticPrograms we will walk through a simple example. Consider the following stochastic program: (taken from [Introduction to Stochastic Programming](https://link.springer.com/book/10.1007%2F978-1-4614-0237-4))

```math
\DeclareMathOperator*{\minimize}{minimize}
\begin{aligned}
 \minimize_{x_1, x_2 \in \mathbb{R}} & \quad 100x_1 + 150x_2 + \operatorname{\mathbb{E}}_{\omega} \left[Q(x_1,x_2,\xi)\right] \\
 \text{s.t.} & \quad x_1+x_2 \leq 120 \\
 & \quad x_1 \geq 40 \\
 & \quad x_2 \geq 20
\end{aligned}
```
where
```math
\begin{aligned}
 Q(x_1,x_2,\xi) = \min_{y_1,y_2 \in \mathbb{R}} & \quad q_1(\xi)y_1 + q_2(\xi)y_2 \\
 \text{s.t.} & \quad 6y_1+10y_2 \leq 60x_1 \\
 & \quad 8y_1 + 5y_2 \leq 80x_2 \\
 & \quad 0 \leq y_1 \leq d_1(\xi) \\
 & \quad 0 \leq y_2 \leq d_2(\xi)
\end{aligned}
```
and the stochastic variable
```math
  \xi = \begin{pmatrix}
    d_1 & d_2 & q_1 & q_2
  \end{pmatrix}^T
```
takes on the value
```math
  \xi_1 = \begin{pmatrix}
    500 & 100 & -24 & -28
  \end{pmatrix}^T
```
with probability ``0.4`` and
```math
  \xi_1 = \begin{pmatrix}
    300 & 300 & -28 & -32
  \end{pmatrix}^T
```
with probability ``0.6``. In the following, we consider how to model, analyze, and solve this stochastic program using StochasticPrograms.

## Scenario definition

First, we introduce a scenario structure

## Optimal first stage decision
