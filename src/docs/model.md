# Modeling

The first step when using RELOG is to describe the reverse logistics pipeline and the relevant data. RELOG accepts as input a JSON file with three sections: `parameters`, `products` and `plants`. Below, we describe each section in more detail.

## Parameters

The **parameters** section describes details about the simulation itself.

| Key                     | Description
|:------------------------|---------------|
|`time periods`           | Number of time periods in the simulation.


### Example
```json
{
    "parameters": {
        "time periods": 2
    }
}
```

## Products

The **products** section describes all products and subproducts in the simulation. The field `instance["products"]` is a dictionary mapping the name of the product to a dictionary which describes its characteristics. Each product description contains the following keys:

| Key                     | Description
|:------------------------|---------------|
|`transportation cost`    | The cost (in dollars per km per tonnes) to transport this product. Must be a timeseries.
|`initial amounts`        | A dictionary mapping the name of each location to its description (see below). If this product is not initially available, this key may be omitted. Must be a timeseries.

Each product may have some amount available at the beginning of each time period. In this case, the key `initial amounts` maps to a dictionary with the following keys:

| Key                     | Description
|:------------------------|---------------|
| `latitude`              | The latitude of the location, in degrees.
| `longitude`             | The longitude of the location, in degrees.
| `amount`                | The amount (in tonnes) of the product initially available at the location. Must be a timeseries.

### Example

```json
{
    "products": {
        "P1": {
            "transportation cost": [0.015, 0.015],
            "initial amounts": {
                "C1": {
                    "latitude": 7.0,
                    "longitude": 7.0,
                    "amount": [934.56, 934.56]
                },
                "C2": {
                    "latitude": 7.0,
                    "longitude": 19.0,
                    "amount": [198.95, 198.95]
                },
                "C3": {
                    "latitude": 84.0,
                    "longitude": 76.0,
                    "amount": [212.97, 212.97]
                }
            }
        },
        "P2": {
            "transportation cost": [0.02, 0.02]
        },
        "P3": {
            "transportation cost": [0.0125, 0.0125]
        },
        "P4": {
            "transportation cost": [0.0175, 0.0175]
        }
    }
}
```

## Processing Plants

The **plants** section describes the available types of reverse manufacturing plants, their potential locations and associated costs, as well as their inputs and outputs. The field `instance["plants"]` is a dictionary mapping the name of the plant to a dictionary with the following keys:

| Key                     | Description
|:------------------------|---------------|
| `input`                 | The name of the product that this plant takes as input. Only one input is accepted per plant.
| `outputs`               | A dictionary specifying how many tonnes of each product is produced for each tonnes of input. For example, if the plant outputs 0.5 tonnes of P2 and 0.25 tonnes of P3 for each tonnes of P1 provided, then this entry should be `{"P2": 0.5, "P3": 0.25}`. If the plant does not output anything, this key may be omitted.
| `locations`             | A dictionary mapping the name of the location to a dictionary which describes the site characteristics (see below).

Each type of plant is associated with a set of potential locations where it can be built. Each location is represented by a dictionary with the following keys:

| Key                     | Description
|:------------------------|---------------|
| `latitude`              | The latitude of the location, in degrees.
| `longitude`             | The longitude of the location, in degrees.
| `disposal`              | A dictionary describing what products can be disposed locally at the plant.
| `capacities`            | A dictionary describing what plant sizes are allowed, and their characteristics.

The keys in the `disposal` dictionary should be the names of the products. The values are dictionaries with the following keys:

| Key                     | Description
|:------------------------|---------------|
| `cost`                  | The cost (in dollars per tonnes) to dispose of the product. Must be a timeseries.
| `limit`                 | The maximum amount (in tonnes) that can be disposed of. If an unlimited amount can be disposed, this key may be omitted. Must be a timeseries.


The keys in the `capacities` dictionary should be the amounts (in tonnes). The values are dictionaries with the following keys:

| Key                     | Description
|:------------------------|---------------|
| `opening cost`          | The cost (in dollars) to open a plant of this size.
| `fixed operating cost`  | The cost (in dollars) to keep the plant open, even if the plant doesn't process anything. Must be a timeseries.
| `variable operating cost` | The cost (in dollars per tonnes) that the plant incurs to process each tonne of input. Must be a timeseries.

### Example

```json
{
    "plants": {
        "F1": {
            "input": "P1",
            "outputs": {
                "P2": 0.2,
                "P3": 0.5
            },
            "locations": {
                "L1": {
                    "latitude": 0.0,
                    "longitude": 0.0,
                    "disposal": {
                        "P2": {
                            "cost": [-10.0, -12.0],
                            "limit": [1.0, 1.0]
                        }
                    },
                    "capacities": {
                        "100": {
                            "opening cost": [500, 530],
                            "fixed operating cost": [300.0, 310.0],
                            "variable operating cost": [5.0, 5.2]
                        },
                        "500": {
                            "opening cost": [750, 760],
                            "fixed operating cost": [400.0, 450.0],
                            "variable operating cost": [4.5, 4.7]
                        },
                        "700": {
                            "opening cost": [1000, 1000],
                            "fixed operating cost": [500.0, 600.0],
                            "variable operating cost": [4.0, 4.4]
                        }
                    }
                }
            }
        }
    }
}
```

Model Assumptions
-----------------
* Each plant can only be opened exactly once. After open, the plant remains open until the end of the simulation.
* Plants can be expanded at any time, even long after they are open.
* All material available at the beginning of a time period must be entirely processed by the end of that time period. It is not possible to store unprocessed materials from one time period to the next.

