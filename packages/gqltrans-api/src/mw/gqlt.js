
const { getGraphQLParams } = require('express-graphql')
const { Source, execute, parse, validate } = require('graphql')
const { print } = require('graphql/language')
const { transformQuery, transformSchema, buildSchema } = require('@mitoai/gqltrans')
const fetch = require('node-fetch')
const httpError = require('http-errors')
const config = require('config')
const auth = require('../auth')

const apiUrl = config.get('upstream.url')

async function fetchFromUpstream(transformation, originalQueryAst, variables, operationName, authorized) {
  const token = authorized ? await auth() : null
  try {
    const newQueryAst = transformQuery(transformation, originalQueryAst)
    const res = await fetch(apiUrl, {
      method: 'POST',
      body: JSON.stringify(
        {
          query: print(newQueryAst),
          variables,
          operationName
        }
      ),
      headers: {
        "Content-Type": "application/json",
        "Authorization": token ? `Bearer ${token}` : undefined
      }
    })
    return await res.json()
  } catch (err) {
    return { errors: [err] }
  }

}

async function exec(transformation, schema, query, variables, operationName, authorized) {
  if (!query) {
    throw httpError(400, 'Must provide query string.');
  }
  const source = new Source(query)
  let documentAst
  try {
    documentAst = parse(source);
  } catch (err) {
    return { errors: [err] }
  }
  const ves = validate(schema, documentAst)
  if (ves.length) {
    return { errors: ves }
  }
  // TODO check mutation vs method
  const upstreamResult = await fetchFromUpstream(transformation, documentAst, variables, operationName, authorized)
  const result = await execute(
    schema,
    documentAst,
    upstreamResult.data,
    null,
    variables,
    operationName,
    (value, x1, x2, { path: { key } }) => value[key]
  )
  const errors = [...(result.errors || []), ...((upstreamResult.errors || []).map(({ locations, ...rest }) => rest))]
  return {
    data: result.data,
    errors: errors.length ? errors : undefined
  }

}

module.exports = function ({ schema, transformation }) {
  const t = transformSchema(schema, transformation)
  const s = buildSchema(t)
  return async ctx => {
    const params = await getGraphQLParams(ctx.req);

    const query = params.query;
    const variables = params.variables;
    const operationName = params.operationName;

    if (!query) {
      throw httpError(400, 'Must provide query string.');
    }

    const result = await exec(t, s, query, variables, operationName, !!ctx.state.authorized)
    ctx.response.type = 'application/json';
    ctx.response.body = JSON.stringify(result);
  }
}