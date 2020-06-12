# Modeling

The first step when using RELOG is to describe the reverse logistics pipeline and the relevant data. RELOG accepts as input a JSON file with three sections: `parameters`, `products` and `plants`. Below, we describe each section in more detail.

## Parameters

The **parameters** section describes details about the simulation itself.

| Key                     | Description
|:------------------------|---------------|
|`Time horizon (years)`   | Number of years in the simulation.


### Example
```json
{
    "Parameters": {
        "Time horizon (years)": 2
    }
}
```

## Products

The **products** section describes all products and subproducts in the simulation. The field `instance["Products"]` is a dictionary mapping the name of the product to a dictionary which describes its characteristics. Each product description contains the following keys:

| Key                                   | Description
|:--------------------------------------|---------------|
|`Transportation cost ($/km/tonne)`     | The cost to transport this product. Must be a timeseries.
|`Transportation energy (J/km/tonne)`   | The energy required to transport this product. Must be a timeseries. Optional.
|`Transportation emissions (tonne/km/tonne)`  | A dictionary mapping the name of each greenhouse gas, produced to transport one tonne of this product along one kilometer, to the amount of gas produced (in tonnes). Must be a timeseries. Optional.
|`Initial amounts`                      | A dictionary mapping the name of each location to its description (see below). If this product is not initially available, this key may be omitted. Must be a timeseries.

Each product may have some amount available at the beginning of each time period. In this case, the key `initial amounts` maps to a dictionary with the following keys:

| Key                     | Description
|:------------------------|---------------|
| `Latitude (deg)`        | The latitude of the location.
| `Longitude (deg)`       | The longitude of the location.
| `Amount (tonne)`       | The amount of the product initially available at the location. Must be a timeseries.

### Example

```json
{
    "Products": {
        "P1": {
            "Initial amounts": {
                "C1": {
                    "Latitude (deg)": 7.0,
                    "Longitude (deg)": 7.0,
                    "Amount (tonne)": [934.56, 934.56]
                },
                "C2": {
                    "Latitude (deg)": 7.0,
                    "Longitude (deg)": 19.0,
                    "Amount (tonne)": [198.95, 198.95]
                },
                "C3": {
                    "Latitude (deg)": 84.0,
                    "Longitude (deg)": 76.0,
                    "Amount (tonne)": [212.97, 212.97]
                }
            },
            "Transportation cost ($/km/tonne)": [0.015, 0.015],
            "Transportation energy (J/km/tonne)": [0.12, 0.11],
            "Transportation emissions (tonne/km/tonne)": {
                "CO2": [0.052, 0.050],
                "CH4": [0.003, 0.002]
            }
        },
        "P2": {
            "Transportation cost ($/km/tonne)": [0.022, 0.020]
        },
        "P3": {
            "Transportation cost ($/km/tonne)": [0.0125, 0.0125]
        },
        "P4": {
            "Transportation cost ($/km/tonne)": [0.0175, 0.0175]
        }
    }
}
```

## Processing Plants

The **plants** section describes the available types of reverse manufacturing plants, their potential locations and associated costs, as well as their inputs and outputs. The field `instance["Plants"]` is a dictionary mapping the name of the plant to a dictionary with the following keys:

| Key                     | Description
|:------------------------|---------------|
| `Input`                 | The name of the product that this plant takes as input. Only one input is accepted per plant.
| `Outputs (tonne)`               | A dictionary specifying how many tonnes of each product is produced for each tonnes of input. For example, if the plant outputs 0.5 tonnes of P2 and 0.25 tonnes of P3 for each tonnes of P1 provided, then this entry should be `{"P2": 0.5, "P3": 0.25}`. If the plant does not output anything, this key may be omitted.
| `Locations`             | A dictionary mapping the name of the location to a dictionary which describes the site characteristics (see below).

Each type of plant is associated with a set of potential locations where it can be built. Each location is represented by a dictionary with the following keys:

| Key                           | Description
|:------------------------------|---------------|
| `Latitude (deg)`              | The latitude of the location, in degrees.
| `Longitude (deg)`             | The longitude of the location, in degrees.
| `Disposal`                    | A dictionary describing what products can be disposed locally at the plant.
| `Capacities (tonne)`         | A dictionary describing what plant sizes are allowed, and their characteristics.

The keys in the `disposal` dictionary should be the names of the products. The values are dictionaries with the following keys:

| Key                     | Description
|:------------------------|---------------|
| `Cost ($/tonne)`       | The cost to dispose of the product. Must be a timeseries.
| `Limit (tonne)`        | The maximum amount that can be disposed of. If an unlimited amount can be disposed, this key may be omitted. Must be a timeseries.


The keys in the `capacities` dictionary should be the amounts (in tonnes). The values are dictionaries with the following keys:

| Key                                   | Description
|:--------------------------------------|---------------|
| `Opening cost ($)`                    | The cost to open a plant of this size.
| `Fixed operating cost ($)`            | The cost to keep the plant open, even if the plant doesn't process anything. Must be a timeseries.
| `Variable operating cost ($/tonne)`  | The cost that the plant incurs to process each tonne of input. Must be a timeseries.

### Example

```json
{
    "Plants": {
        "F1": {
            "Input": "P1",
            "Outputs (tonne)": {
                "P2": 0.2,
                "P3": 0.5
            },
            "Locations": {
                "L1": {
                    "Latitude (deg)": 0.0,
                    "Longitude (deg)": 0.0,
                    "Disposal": {
                        "P2": {
                            "Cost ($/tonne)": [-10.0, -12.0],
                            "Limit (tonne)": [1.0, 1.0]
                        }
                    },
                    "Capacities (tonne)": {
                        "100": {
                            "Opening cost ($)": [500, 530],
                            "Fixed operating cost ($)": [300.0, 310.0],
                            "Variable operating cost ($/tonne)": [5.0, 5.2]
                        },
                        "500": {
                            "Opening cost ($)": [750, 760],
                            "Fixed operating cost ($)": [400.0, 450.0],
                            "Variable operating cost ($/tonne)": [5.0, 5.2]
                        }
                    }
                }
            }
        }
    }
}
```

## Current limitations

* Each plant can only be opened exactly once. After open, the plant remains open until the end of the simulation.
* Plants can be expanded at any time, even long after they are open.
* All material available at the beginning of a time period must be entirely processed by the end of that time period. It is not possible to store unprocessed materials from one time period to the next.
* Up to two plant sizes are currently supported. Variable operating costs must be the same for all plant sizes.