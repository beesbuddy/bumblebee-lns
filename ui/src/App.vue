<template>
  <div class="min-h-screen px-6 py-12 md:px-12">
    <div class="mx-auto flex max-w-6xl flex-col gap-10">
      <header class="grid items-center gap-6 md:grid-cols-[2fr,1fr]">
        <div class="glass-panel rounded-3xl border border-base-300 p-8 shadow-xl">
          <p class="badge badge-secondary mb-4 uppercase tracking-wide">Vue + Tailwind + DaisyUI</p>
          <h1 class="font-display text-4xl font-semibold leading-tight md:text-5xl">
            Build and ship reactive UI straight from Cowboy.
          </h1>
          <p class="mt-4 text-lg text-base-content/80">
            Hot reload in dev builds, minified assets for prod. Switch with <code>RUNLET_FRONTEND_ENV</code>
            and keep serving from Erlang.
          </p>
          <div class="mt-6 flex flex-wrap gap-3">
            <button class="btn btn-primary shadow-lg">Launch demo</button>
            <button class="btn btn-ghost">View endpoints</button>
          </div>
        </div>
        <div class="grid gap-4">
          <div class="stats shadow-lg">
            <div class="stat">
              <div class="stat-title">Mode</div>
              <div class="stat-value text-primary">Dev / Prod</div>
              <div class="stat-desc">Controlled by env</div>
            </div>
            <div class="stat">
              <div class="stat-title">Builds</div>
              <div class="stat-value text-accent">Vite</div>
              <div class="stat-desc">triggered from Erlang</div>
            </div>
          </div>
          <div class="card shadow-lg">
            <div class="card-body">
              <h2 class="card-title">Hello, Cowboy!</h2>
              <p class="text-base-content/80">
                The backend stays simple: `/hello` returns text, everything else serves the Vue app.
              </p>
              <div class="card-actions">
                <a class="btn btn-outline btn-sm" href="/hello">Try /hello</a>
              </div>
            </div>
          </div>
        </div>
      </header>

      <section class="grid gap-6 md:grid-cols-3">
        <article class="card border border-base-300 bg-base-100/60 shadow-md">
          <div class="card-body">
            <h3 class="card-title text-lg">Tailwind utilities</h3>
            <p class="text-base-content/80">
              Compose layouts quickly with utility classes and keep styles consistent.
            </p>
            <div class="badge badge-primary badge-outline mt-3 w-fit">Ready</div>
          </div>
        </article>
        <article class="card border border-base-300 bg-base-100/60 shadow-md">
          <div class="card-body">
            <h3 class="card-title text-lg">DaisyUI components</h3>
            <p class="text-base-content/80">
              Buttons, badges, cards, stats, and more with themeable tokens.
            </p>
            <div class="badge badge-accent badge-outline mt-3 w-fit">Styled</div>
          </div>
        </article>
        <article class="card border border-base-300 bg-base-100/60 shadow-md">
          <div class="card-body">
            <h3 class="card-title text-lg">Vue 3 + Vite</h3>
            <p class="text-base-content/80">
              Fast dev server, production-optimized bundles, and single-file components.
            </p>
            <div class="badge badge-secondary badge-outline mt-3 w-fit">Bundled</div>
          </div>
        </article>
      </section>
    </div>
  </div>
</template>

<style scoped>
code {
  @apply rounded bg-base-300 px-2 py-1 text-sm;
}
</style>
