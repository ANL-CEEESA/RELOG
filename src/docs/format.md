# Data Format

The first step when using RELOG is to describe the reverse logistics pipeline and the relevant data. RELOG accepts as input a JSON file with three sections: `parameters`, `products` and `plants`. Below, we describe each section in more detail.

## Parameters

The **parameters** section describes details about the simulation itself.

| Key                       | Description
|:--------------------------|---------------|
|`time horizon (years)`     | Number of years in the simulation.
|`building period (years)`  | List of years in which we are allowed to open new plants. For example, if this parameter is set to `[1,2,3]`, we can only open plants during the first three years. By default, this equals `[1]`; that is, plants can only be opened during the first year. |


### Example
```json
{
    "parameters": {
        "time horizon (years)": 2,
        "building period (years)": [1]
    }
}
```

## Products

The **products** section describes all products and subproducts in the simulation. The field `instance["Products"]` is a dictionary mapping the name of the product to a dictionary which describes its characteristics. Each product description contains the following keys:

| Key                                   | Description
|:--------------------------------------|---------------|
|`transportation cost ($/km/tonne)`     | The cost to transport this product. Must be a timeseries.
|`transportation energy (J/km/tonne)`   | The energy required to transport this product. Must be a timeseries. Optional.
|`transportation emissions (tonne/km/tonne)`  | A dictionary mapping the name of each greenhouse gas, produced to transport one tonne of this product along one kilometer, to the amount of gas produced (in tonnes). Must be a timeseries. Optional.
|`initial amounts`                      | A dictionary mapping the name of each location to its description (see below). If this product is not initially available, this key may be omitted. Must be a timeseries.

Each product may have some amount available at the beginning of each time period. In this case, the key `initial amounts` maps to a dictionary with the following keys:

| Key                     | Description
|:------------------------|---------------|
| `latitude (deg)`        | The latitude of the location.
| `longitude (deg)`       | The longitude of the location.
| `amount (tonne)`       | The amount of the product initially available at the location. Must be a timeseries.

### Example

```json
{
    "products": {
        "P1": {
            "initial amounts": {
                "C1": {
                    "latitude (deg)": 7.0,
                    "longitude (deg)": 7.0,
                    "amount (tonne)": [934.56, 934.56]
                },
                "C2": {
                    "latitude (deg)": 7.0,
                    "longitude (deg)": 19.0,
                    "amount (tonne)": [198.95, 198.95]
                },
                "C3": {
                    "latitude (deg)": 84.0,
                    "longitude (deg)": 76.0,
                    "amount (tonne)": [212.97, 212.97]
                }
            },
            "transportation cost ($/km/tonne)": [0.015, 0.015],
            "transportation energy (J/km/tonne)": [0.12, 0.11],
            "transportation emissions (tonne/km/tonne)": {
                "CO2": [0.052, 0.050],
                "CH4": [0.003, 0.002]
            }
        },
        "P2": {
            "transportation cost ($/km/tonne)": [0.022, 0.020]
        },
        "P3": {
            "transportation cost ($/km/tonne)": [0.0125, 0.0125]
        },
        "P4": {
            "transportation cost ($/km/tonne)": [0.0175, 0.0175]
        }
    }
}
```

## Processing Plants

The **plants** section describes the available types of reverse manufacturing plants, their potential locations and associated costs, as well as their inputs and outputs. The field `instance["Plants"]` is a dictionary mapping the name of the plant to a dictionary with the following keys:

| Key                     | Description
|:------------------------|---------------|
| `input`                 | The name of the product that this plant takes as input. Only one input is accepted per plant.
| `outputs (tonne/tonne)`               | A dictionary specifying how many tonnes of each product is produced for each tonnes of input. For example, if the plant outputs 0.5 tonnes of P2 and 0.25 tonnes of P3 for each tonnes of P1 provided, then this entry should be `{"P2": 0.5, "P3": 0.25}`. If the plant does not output anything, this key may be omitted.
|`energy (GJ/tonne)`   | The energy required to process 1 tonne of the input. Must be a timeseries. Optional.
|`emissions (tonne/tonne)`  | A dictionary mapping the name of each greenhouse gas, produced to process each tonne of input, to the amount of gas produced (in tonne). Must be a timeseries. Optional.
| `locations`             | A dictionary mapping the name of the location to a dictionary which describes the site characteristics (see below).

Each type of plant is associated with a set of potential locations where it can be built. Each location is represented by a dictionary with the following keys:

| Key                           | Description
|:------------------------------|---------------|
| `latitude (deg)`              | The latitude of the location, in degrees.
| `longitude (deg)`             | The longitude of the location, in degrees.
| `disposal`                    | A dictionary describing what products can be disposed locally at the plant.
| `capacities (tonne)`         | A dictionary describing what plant sizes are allowed, and their characteristics.

The keys in the `disposal` dictionary should be the names of the products. The values are dictionaries with the following keys:

| Key                     | Description
|:------------------------|---------------|
| `cost ($/tonne)`       | The cost to dispose of the product. Must be a timeseries.
| `limit (tonne)`        | The maximum amount that can be disposed of. If an unlimited amount can be disposed, this key may be omitted. Must be a timeseries.


The keys in the `capacities (tonne)` dictionary should be the amounts (in tonnes). The values are dictionaries with the following keys:

| Key                                   | Description
|:--------------------------------------|---------------|
| `opening cost ($)`                    | The cost to open a plant of this size.
| `fixed operating cost ($)`            | The cost to keep the plant open, even if the plant doesn't process anything. Must be a timeseries.
| `variable operating cost ($/tonne)`  | The cost that the plant incurs to process each tonne of input. Must be a timeseries.

### Example

```json
{
    "plants": {
        "F1": {
            "input": "P1",
            "outputs (tonne/tonne)": {
                "P2": 0.2,
                "P3": 0.5
            },
            "energy (GJ/tonne)": [0.12, 0.11],
            "emissions (tonne/tonne)": {
                "CO2": [0.052, 0.050],
                "CH4": [0.003, 0.002]
            },
            "locations": {
                "L1": {
                    "latitude (deg)": 0.0,
                    "longitude (deg)": 0.0,
                    "disposal": {
                        "P2": {
                            "cost ($/tonne)": [-10.0, -12.0],
                            "limit (tonne)": [1.0, 1.0]
                        }
                    },
                    "capacities (tonne)": {
                        "100": {
                            "opening cost ($)": [500, 530],
                            "fixed operating cost ($)": [300.0, 310.0],
                            "variable operating cost ($/tonne)": [5.0, 5.2]
                        },
                        "500": {
                            "opening cost ($)": [750, 760],
                            "fixed operating cost ($)": [400.0, 450.0],
                            "variable operating cost ($/tonne)": [5.0, 5.2]
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