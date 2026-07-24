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

function validateSignature(body, secret, signature) {
    console.log("Validating request...")
    var hash = crypto.createHmac(process.env.GITHUB_WEBHOOK_HASHALG, secret)
        .update(JSON.stringify(body))
        .digest('hex');
    return (hash === signature.split("=")[1]);
}

// Promise wrapper för exec med timeout
function execPromise(command, options = {}) {
    return new Promise((resolve, reject) => {
        const timeout = options.timeout || 300000 // 5 minuter default
        
        const child = exec(command, { 
            ...options,
            timeout: timeout 
        }, (error, stdout, stderr) => {
            if (error) {
                reject({ error, stdout, stderr })
            } else {
                resolve({ stdout, stderr })
            }
        })
        
        // Logga output i realtid
        child.stdout.on('data', (data) => {
            process.stdout.write(data)
        })
        child.stderr.on('data', (data) => {
            process.stderr.write(data)
        })
    })
}

apiRoutes.get('/', function (req, res, next) {
    res.end("KTH Biblioteket Webhooks för Apps")
});

apiRoutes.post('/', async function (req, res, next) {
    // Validera signature
    if (!validateSignature(req.body, webhook_secret, req.get(process.env.GITHUB_WEBHOOK_SIGNATURE_HEADER))) {
        return res.status(401).send({ 
            errorMessage: 'Invalid Signature',
            timestamp: new Date().toISOString()
        })
    }
    
    console.log("✅ Signature is valid")
    console.log("📦 Received payload:", JSON.stringify(req.body, null, 2))

    var action = req.body.data.action.toLowerCase()
    
    switch (action) {
        case "deploy":
            console.log("🚀 Start deploy...")
            
            const script = process.env.GITHUB_WEBHOOK_DEPLOY_SCRIPT
            const event = req.body.event
            const repository = req.body.repository.split("/")[1]
            const commit = req.body.commit
            const dockerPath = process.env.WEBHOOK_DOCKER_PATH
            
            if (!script) {
                console.error("❌ GITHUB_WEBHOOK_DEPLOY_SCRIPT not set in environment")
                return res.status(500).send({ 
                    errorMessage: 'Deploy script not configured',
                    timestamp: new Date().toISOString()
                })
            }
            
            const command = `${script} ${event} ${repository} ${commit} ${action} ${dockerPath}`
            console.log(`📋 Running: ${command}`)
            
            try {
                const { stdout, stderr } = await execPromise(command, {
                    timeout: 600000, // 10 minuter timeout
                    maxBuffer: 50 * 1024 * 1024 // 50MB buffer
                })
                
                console.log("✅ Deploy completed successfully")
                
                // Returnera success
                return res.status(200).send({
                    status: 'success',
                    message: 'Deployment completed',
                    timestamp: new Date().toISOString(),
                    repository: repository,
                    commit: commit
                })
                
            } catch (error) {
                console.error("❌ Deploy failed")
                
                // Logga detaljer
                if (error.error) {
                    console.error("Error:", error.error.message)
                    console.error("Code:", error.error.code)
                }
                if (error.stdout) {
                    console.log("stdout:", error.stdout)
                }
                if (error.stderr) {
                    console.error("stderr:", error.stderr)
                }
                
                // Returnera fel
                return res.status(500).send({
                    status: 'error',
                    errorMessage: 'Deployment failed',
                    details: error.error ? error.error.message : String(error),
                    timestamp: new Date().toISOString(),
                    repository: repository,
                    commit: commit
                })
            }
            
        default:
            console.log('⚠️ No handler for type:', action)
            return res.status(204).send()
    }
})

// Global error handler
app.use((err, req, res, next) => {
    console.error('❌ Unhandled error:', err)
    res.status(500).send({
        errorMessage: 'Internal server error',
        timestamp: new Date().toISOString()
    })
})