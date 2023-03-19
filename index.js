require('dotenv').config()
const express = require('express')
const bodyParser = require('body-parser');
const crypto = require('crypto');
const { exec } = require('child_process');
const process = require("process");

const app = express()
const port = process.env.WEBHOOK_PORT
const webhook_secret = process.env.WEBHOOK_SECRET

app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

const apiRoutes = express.Router();

app.use('/hook', apiRoutes);

app.listen(port, (err) => {
    if (err) {
        return console.log('Error: ', err)
    }
    console.log(`server is listening on ${port}`)
})

function cmd(...command) {
    let p = exec(command[0], command.slice(1));
    return new Promise((resolve) => {
        p.stdout.on("data", (x) => {
            process.stdout.write(x.toString());
        });
        p.stderr.on("data", (x) => {
            process.stderr.write(x.toString());
        });
        p.on("exit", (code) => {
            resolve(code);
        });
    });
}

function validateSignature(body, secret, signature) {
    console.log("Validating request...")
    var hash = crypto.createHmac(process.env.GITHUB_WEBHOOK_HASHALG, secret)
        .update(JSON.stringify(body))
        .digest('hex');
    return (hash === signature.split("=")[1]);
}

apiRoutes.get('/', function (req, res, next) {
    res.end("KTH Biblioteket Webhooks för Apps")
});

apiRoutes.post('/', async function (req, res, next) {
    if (!validateSignature(req.body, webhook_secret, req.get(process.env.GITHUB_WEBHOOK_SIGNATURE_HEADER))) {
        return res.status(401).send({ errorMessage: 'Invalid Signature' });
    }
    console.log("Signature is valid")
    console.log("Received payload")
    console.log(req.body)

    var action = req.body.data.action.toLowerCase();
    switch (action) {
        case "deploy":
            // Kör deploy-script
            console.log("Start deploy...")
            // await cmd("");
            exec(`${process.env.GITHUB_WEBHOOK_DEPLOY_SCRIPT} ${req.body.event} ${req.body.repository.split("/")[1]} ${req.body.commit} ${action} ${process.env.WEBHOOK_DOCKER_PATH}`, (error, stdout, stderr) => {
                if (error) {
                    console.error(`exec error: ${error}`);
                    return res.status(401).send({ errorMessage: error });
                }
                console.log(stdout);
            });
            console.log("Finished deploy...")
            break;
        default:
            console.log('No handler for type', action);
    }
    res.status(204).send();
});