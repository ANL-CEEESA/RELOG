# Optimizing

After creating a JSON file describing the reverse manufacturing process and the input data, the following example illustrates how to use the package to find the optimal set of decisions:

```julia
using RELOG
RELOG.solve("/home/user/instance.json")
```

The optimal logistics plan will be printed to the screen.

