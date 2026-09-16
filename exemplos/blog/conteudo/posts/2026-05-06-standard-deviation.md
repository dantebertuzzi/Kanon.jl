+++
idioma = "en"
titulo = "Standard deviation without the mystery"
descricao = "What the standard deviation measures, how to compute it by hand, and why the sample version divides by n − 1."
autor = "dante-bertuzzi"
data = 2026-05-06
tags = ["Statistics", "Dispersion"]
ref = "desvio-padrao"
+++

Two groups of students scored the same average, 7. In the first, the scores were 6, 7 and
8; in the second, 4, 7 and 10. The mean cannot tell the groups apart — and that difference
is exactly what the standard deviation measures.

## Distance from the mean

For each value, take its distance to the mean, square it so that positive and negative
distances do not cancel, and average the squares. That average is the **variance**; its
square root brings the measure back to the original unit:

$$ \sigma = \sqrt{\frac{1}{N}\sum_{i=1}^{N}(x_i - \mu)^2} $$

For the second group, the squares are 9, 0 and 9, their mean is 6, and
$\sigma = \sqrt{6} \approx 2.45$.

## Why a sample divides by n − 1

When the mean $\bar{x}$ is computed from the sample itself, the deviations are, on average,
smaller than they would be around the true mean. Dividing by $n - 1$ corrects that bias.
