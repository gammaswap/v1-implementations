//import * as React from 'react';
import React, { useState, useEffect } from 'react'
import { BigNumber, constants } from 'ethers'
import Borrow from './Borrow';
import Lend from './Lend';
import Statistics from './Statistics';
import { Tabs, TabList, TabPanels, Tab, TabPanel, Container, Heading } from '@chakra-ui/react';

function TabGroup(props) {

    return (
        <Container>
            <Statistics depPool={props.depPool} token0={props.token0} token1={props.token1}/>
            <Tabs variant='soft-rounded' colorScheme={'purple'}>
                <TabList>
                    <Tab textColor={'#e2e8f0'}>Deposit</Tab>
                    <Tab textColor={'#e2e8f0'}>Borrow</Tab>
                </TabList>
                <TabPanels>
                    <TabPanel>
                        <Lend
                            depPool={props.depPool}
                            account={props.account}
                            token0={props.token0}
                            token1={props.token1} 
                        />
                    </TabPanel>
                    <TabPanel>
                        <Borrow
                            posManager={props.posManager}
                            account={props.account}
                            token0={props.token0}
                            token1={props.token1}
                        />
                    </TabPanel>
                </TabPanels>
            </Tabs>
        </Container>
    )
}
export default TabGroup
