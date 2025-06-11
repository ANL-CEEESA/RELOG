export interface CircularPlant {
    id: string;
    x: number;
    y: number;

    input?: string; // optional product name

}

export interface CircularProduct { 
    id: string;
    x: number;
    y: number;
}

export interface CircularData {
    plants: Record<string, CircularPlant>;

    products: Record<string, CircularProduct>;

    parameters: Record<string, any>; // Any parameters, ex: simulation years, costs 

}