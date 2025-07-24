export interface PlantNode {
    uid: string;
    name: string;
    x: number;
    y: number;
    inputs: string[];
    outputs: string[];


}

export interface ProductNode { 
    uid: string;
    name: string;
    x: number;
    y: number;
}


export interface CenterNode {
    uid: string;
    name: string;
    x: number;
    y: number;

    //single input, multiple outputs 
    input?: string;
    output: string[];
}


export interface InitialData {
    plants: Record<string, PlantNode>;
    products: Record<string, ProductNode>;
    centers: Record<string, CenterNode>;


}

export interface RELOGScenario {
    Parameters: {
        version: string;
    };

    Plants: Record<string, PlantNode>;
    Products: Record< string, ProductNode>;
    Centers: Record<string,CenterNode>;
}