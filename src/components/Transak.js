import * as React from 'react';
import {
    Container,
    Stack,
    Heading,
    Text,
    Button,
} from '@chakra-ui/react';
import transakSDK from "@transak/transak-sdk";

const settings = {
    apiKey: '4da97dbb-416a-4061-ad9c-fb597ae3643f',  // Your API Key
    environment: 'STAGING', // STAGING/PRODUCTION
    defaultCryptoCurrency: 'ETH',
    themeColor: '000000', // App theme color
    hostURL: window.location.origin,
    widgetHeight: "700px",
    widgetWidth: "500px",
}

export function openTransak() {
    const transak = new transakSDK(settings);

    transak.init();

    // To get all the events
    transak.on(transak.ALL_EVENTS, (data) => {
        console.log(data)
    });

    // This will trigger when the user closed the widget
    transak.on(transak.EVENTS.TRANSAK_WIDGET_CLOSE, (eventData) => {
        console.log(eventData);
        transak.close();
    });

    // This will trigger when the user marks payment is made.
    transak.on(transak.EVENTS.TRANSAK_ORDER_SUCCESSFUL, (orderData) => {
        console.log(orderData);
        window.alert("Payment Success")
        transak.close();
    });
}


function Transak() {
    return (
        <Container>
            <Stack>
                <Heading fontSize={'5xl'} color={'#e2e8f0'}>Begin your Gamma Future Now!</Heading>
                <Button onClick={() => openTransak()}>
                    Buy Crypto With Cash 💸
                </Button>
            </Stack>
        </Container>
    );
}

export default Transak;