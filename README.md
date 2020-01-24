ReverseManufacturing.jl
=======================

**ReverseManufacturing.jl** is an optimization package for logistic decisions related to reverse manufacturing processes. For example, the package can be used to determine where to build recycling plants, what sizes should they have and which customers should be served by which plants. The package supports customized reverse manufacturing pipelines, with multiple types of plants, multiple types of product and multiple time periods.


Data Specification
==================

Each instance in ReverseManufacturing.jl is represented as a JSON file with two sections: `products` and `plants`. Below, we describe each section in more detail. For a concrete example, see the file `instances/samples/s2.json`.

Products
--------

The **products** section describes all products and subproducts in the simulation. The field `instance["products"]` is a dictionary mapping the name of the product to a dictionary which describes its characteristics. Each product description contains the following keys:

| Key                           | Description
|:------------------------------|:-----------------------------------
| `transportation cost` | The cost (in dollars per km) to transport this product
| `initial amounts`     | A dictionary mapping the name of each location to its description. See below for more information. If this product is not initially available, this key may be omitted.

Each product may have some amount available at the beginning of the simulation. In this case, the key `initial amounts` maps to a dictionary with the following keys:

| Key                           | Description
|:------------------------------|:-----------------------------------
| `latitude`                    | The latitude of the location, in degrees.
| `longitude`                   | The longitude of the location, in degrees.
| `amount`                      | The amount (in kg) of the product initially available at the location.

Processing Plants
-----------------

The **plants** section describes the available types of reverse manufacturing plants, their potential locations and associated costs, as well as their inputs and outputs. The field `instance["plants"]` is a dictionary mapping the name of the plant to a dictionary with the following keys:

| Key                           | Description
|:------------------------------|:-----------------------------------
| `input`             | The name of the product that this plant takes as input. Only one input is accepted per plant.
| `outputs`           | A dictionary specifying how many kg of each product is produced for each kg of input. For example, if the plant outputs 0.5 kg of P2 and 0.25 kg of P3 for each kg of P1 provided, then this entry should be `{"P2": 0.5, "P3": 0.25}`. If the plant does not output anything, this key may be omitted.
| `locations` | A dictionary mapping the name of the location to a dictionary which describes the site characteristics. See below for a more detailed explanation.

Each type of plant is associated with a set of potential locations. Each location is represented by a dictionary with the following keys:

| Key                           | Description
|:------------------------------|:-----------------------------------
| `latitude`                    | The latitude of the location, in degrees.
| `longitude`                   | The longitude of the location, in degrees.
| `opening cost`                | The cost (in dollars) to open the plant.
| `fixed operating cost`        | The cost (in dollars) to keep the plant open, even if the plant doesn't process anything.
| `variable operating cost`     | The cost (in dollars per kg) that the plant incurs to process each kg of input.


Authors
=======
* **Alinson S. Xavier,** Argonne National Laboratory <<axavier@anl.gov>>
* **Nwike Iloeje,** Argonne National Laboratory <<ciloeje@anl.gov>>