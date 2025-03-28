# Input data format

RELOG accepts as input a JSON file with four sections: `parameters`, `products`, `centers` and `plants`. Below, we describe each section in more detail.

## Parameters

| Key                       | Description                                                                                                                                                                                                                                                  |
| :------------------------ | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `time horizon (years)`    | Number of years in the simulation.                                                                                                                                                                                                                           |
| `building period (years)` | List of years in which we are allowed to open new plants. For example, if this parameter is set to `[1,2,3]`, we can only open plants during the first three years. By default, this equals `[1]`; that is, plants can only be opened during the first year. |
| `distance metric`         | Metric used to compute distances between pairs of locations. Valid options are: `"Euclidean"`, for the straight-line distance between points; or `"driving"` for an approximated driving distance. If not specified, defaults to `"Euclidean"`.              |

#### Example

```json
{
  "parameters": {
    "time horizon (years)": 4,
    "building period (years)": [1],
    "distance metric": "driving"
  }
}
```

## Products

| Key                                         | Description                                                                                                                                                                                            |
| :------------------------------------------ | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `transportation cost ($/km/tonne)`          | The cost to transport this product. Must be a time series.                                                                                                                                             |
| `transportation energy (J/km/tonne)`        | The energy required to transport this product. Must be a time series. Optional.                                                                                                                        |
| `transportation emissions (tonne/km/tonne)` | A dictionary mapping the name of each greenhouse gas, produced to transport one tonne of this product along one kilometer, to the amount of gas produced (in tonnes). Must be a time series. Optional. |

#### Example

```json
{
  "products": {
    "P1": {
      "transportation cost ($/km/tonne)": 0.015,
      "transportation energy (J/km/tonne)": 0.12,
      "transportation emissions (tonne/km/tonne)": {
        "CO2": 0.052,
        "CH4": 0.003
      }
    }
  }
}
```

## Centers

| Key                             | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| :------------------------------ | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `latitude (deg)`                | The latitude of the center.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `longitude (deg)`               | The longitude of the center.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| `input`                         | The name of the product this center takes as input from the plants. May be `null` if the center accept no input product.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| `outputs`                       | List of output products collected by the center. May be `[]` if none.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| `fixed output (tonne)`          | Dictionary mapping the name of each output product to the amount generated by this center each year, regardless of how much input the center receives. For example, if this field equals to `{"P1": [1.0, 2.0, 3.0, 4.0]}`, then this center generates 1.0, 2.0, 3.0 and 4.0 tonnes of P2 in years 1, 2, 3 and 4, respectively.                                                                                                                                                                                                                                                                                        |
| `variable output (tonne/tonne)` | Dictionary mapping the name of each output product to the amount of output generated, for each tonne of input material, and for each year after the input is received. For example, in a 4-year simulation, if this field equals to `{"P1": [0.1, 0.3, 0.6, 0.0]}` and the center receives 1.0, 2.0, 3.0 and 4.0 tonnes of input material in years 1, 2, 3 and 4, then the center will produce $1.0 * 0.1 = 0.1$ of P1 in the first year, $1.0 * 0.3 + 2.0 * 0.1 = 0.5$ the second year, $1.0 * 0.6 + 2.0 * 0.3 + 3.0 * 0.1 = 1.5$ in the third year, and $2.0 * 0.6 + 3.0 * 0.3 + 4.0 * 0.1 = 2.5$ in the final year. |
| `revenue ($/tonne)`             | Revenue generated by each tonne of input material sent to the center. If the center accepts no input, this should be `null`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `collection cost ($/tonne)`     | Dictionary mapping the name of each output product to the cost of collecting one tonne of the product.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| `operating cost ($)`            | Fixed cost to operate the center for one year, regardless of amount of product received or generated.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| `disposal limit (tonne)`        | Dictionary mapping the name of each output product to the maximum disposal amount allower per year of the product at the center. Entry may be `null` if unlimited.                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| `disposal cost ($/tonne)`       | Dictionary mapping the name of each output product to the cost to dispose one tonne of the product at the center.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |

```json
{
  "centers": {
    "C1": {
      "latitude (deg)": 41.881,
      "longitude (deg)": -87.623,
      "input": "P1",
      "outputs": ["P2", "P3"],
      "fixed output (tonne)": {
        "P2": [100, 50, 0, 0],
        "P3": [20, 10, 0, 0]
      },
      "variable output (tonne/tonne)": {
        "P2": [0.12, 0.25, 0.12, 0.0],
        "P3": [0.25, 0.25, 0.25, 0.0]
      },
      "revenue ($/tonne)": [12.0, 12.0, 12.0, 12.0],
      "collection cost ($/tonne)": {
        "P2": [0.25, 0.25, 0.25, 0.25],
        "P3": [0.37, 0.37, 0.37, 0.37]
      },
      "operating cost ($)": [150.0, 150.0, 150.0, 150.0],
      "disposal limit (tonne)": {
        "P2": [0, 0, 0, 0],
        "P3": [null, null, null, null]
      },
      "disposal cost ($/tonne)": {
        "P2": [0.23, 0.23, 0.23, 0.23],
        "P3": [1.0, 1.0, 1.0, 1.0]
      }
    },
    "C2": {
      "latitude (deg)": 41.881,
      "longitude (deg)": -87.623,
      "input": null,
      "outputs": ["P4"],
      "variable output (tonne/tonne)": {
        "P4": [0, 0, 0, 0]
      },
      "fixed output (tonne)": {
        "P4": [50, 60, 70, 80]
      },
      "revenue ($/tonne)": null,
      "collection cost ($/tonne)": {
        "P4": [0.25, 0.25, 0.25, 0.25]
      },
      "operating cost ($)": [150.0, 150.0, 150.0, 150.0],
      "disposal limit (tonne)": {
        "P4": [null, null, null, null]
      },
      "disposal cost ($/tonne)": {
        "P4": [0, 0, 0, 0]
      }
    },
    "C3": {
      "latitude (deg)": 41.881,
      "longitude (deg)": -87.623,
      "input": "P1",
      "outputs": [],
      "variable output (tonne/tonne)": {},
      "constant output (tonne)": {},
      "revenue ($/tonne)": [12.0, 12.0, 12.0, 12.0],
      "collection cost ($/tonne)": {},
      "operating cost ($)": [150.0, 150.0, 150.0, 150.0],
      "disposal limit (tonne)": {},
      "disposal cost ($/tonne)": {}
    }
  }
}
```

## Plants

| Key                            | Description                                                                                                                                  |
| :----------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `latitude (deg)`               | The latitude of the plant, in degrees.                                                                                                       |
| `longitude (deg)`              | The longitude of the plant, in degrees.                                                                                                      |
| `input mix (%)`                | Dictionary mapping the name of each input product to the amount required (as a percentage). Must sum to 100%.                                |
| `output (tonne)`               | Dictionary mapping the name of each output product to the amount produced (in tonne) for one tonne of input mix.                             |
| `processing emissions (tonne)` | A dictionary mapping the name of each greenhouse gas, produced to process each tonne of input, to the amount of gas produced (in tonne).     |
| `storage cost ($/tonne)`       | Dictionary mapping the name of each input product to the cost of storing the product for one year at the plant for later processing.         |
| `storage limit (tonne)`        | Dictionary mapping the name of each input product to the maximum amount allowed in storage at any time. May be `null` if unlimited.          |
| `disposal cost ($/tonne)`      | Dictionary mapping the name of each output product to the cost of disposing it at the plant.                                                 |
| `disposal limit (tonne)`       | Dictionary mapping the name of each output product to the maximum amount allowed to be disposed of at the plant. May be `null` if unlimited. |
| `capacities`                   | List describing what plant sizes are allowed, and their characteristics.                                                                     |

The entries in the `capacities` list should be dictionaries with the following
keys:

| Key                                 | Description                                                                                         |
| :---------------------------------- | :-------------------------------------------------------------------------------------------------- |
| `size (tonne)`                      | The size of the plant.                                                                              |
| `opening cost ($)`                  | The cost to open a plant of this size.                                                              |
| `fixed operating cost ($)`          | The cost to keep the plant open, even if the plant doesn't process anything. Must be a time series. |
| `variable operating cost ($/tonne)` | The cost that the plant incurs to process each tonne of input. Must be a time series.               |
| `initial capacity (tonne)`          | Capacity already available. If the plant has not been built yet, this should be `0`.                |

```json
{
  "plants": {
    "L1": {
      "latitude (deg)": 41.881,
      "longitude (deg)": -87.623,
      "input mix (%)": {
        "P1": 95.3,
        "P2": 4.7
      },
      "output (tonne)": {
        "P3": 0.25,
        "P4": 0.12,
        "P5": 0.1
      },
      "processing emissions (tonne)": {
        "CO2": 0.1
      },
      "storage cost ($/tonne)": {
        "P1": 0.1,
        "P2": 0.1
      },
      "storage limit (tonne)": {
        "P1": 100,
        "P2": null
      },
      "disposal cost ($/tonne)": {
        "P3": 0,
        "P4": 0.86,
        "P5": 0.25,
      },
      "disposal limit (tonne)": {
        "P3": null,
        "P4": 1000.0,
        "P5": 1000.0
      },
      "capacities": [
        {
          "size": 100,
          "opening cost ($)": 500,
          "fixed operating cost ($)": 300,
          "variable operating cost ($/tonne)": 5.0
        },
        {
          "size": 500,
          "opening cost ($)": 1000.0,
          "fixed operating cost ($)": 400.0,
          "variable operating cost ($/tonne)": 5.0.
        }
      ],
      "initial capacity (tonne)": 0,
    }
  }
}
```
