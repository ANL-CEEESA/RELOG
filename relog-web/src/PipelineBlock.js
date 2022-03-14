import React from 'react';
import ReactFlow, { Background } from 'react-flow-renderer';
import Section from './Section';
import Card from './Card';
import Button from './Button';
import styles from './PipelineBlock.module.css';

const elements = [
    {
        id: '1',
        data: { label: 'Battery' },
        sourcePosition: 'right',
        targetPosition: 'left',
        position: { x: 100, y: 200 },
        className: styles.ProductNode,
    },
    {
        id: '2',
        data: { label: "Battery Recycling Plant" },
        sourcePosition: 'right',
        targetPosition: 'left',
        position: { x: 500, y: 150 },
        className: styles.PlantNode,
    },
    {
        id: '3',
        data: { label: 'Nickel' },
        sourcePosition: 'right',
        targetPosition: 'left',
        position: { x: 900, y: 100 },
        className: styles.ProductNode,
    },
    {
        id: '4',
        data: { label: 'Metal casing' },
        sourcePosition: 'right',
        targetPosition: 'left',
        position: { x: 900, y: 300 },
        className: styles.ProductNode,
    },
    {
        id: 'e1-2',
        source: '1',
        target: '2',
        animated: true,
        selectable: false,
        style: { stroke: "black" },
    },
    {
        id: 'e2-3',
        source: '2',
        target: '3',
        animated: true,
        selectable: false,
        style: { stroke: "black" },
    },
    {
        id: 'e2-4',
        source: '2',
        target: '4',
        animated: true,
        selectable: false,
        style: { stroke: "black" },
    },

];

const PipelineBlock = () => {
    return (
        <>
            <Section title="Pipeline" />
            <Card>
                <div className={styles.PipelineBlock}>
                    <ReactFlow elements={elements}>
                        <Background />
                    </ReactFlow>
                </div>
                <div style={{ textAlign: 'center' }}>
                    <Button label="Add product" kind="inline" />
                    <Button label="Add plant" kind="inline" />
                </div>
            </Card>
        </>
    )
}

export default PipelineBlock;